#import "RealtimeMarkdownView.h"

#import "react/renderer/components/RNRealtimeMarkdownSpec/ComponentDescriptors.h"
#import "react/renderer/components/RNRealtimeMarkdownSpec/EventEmitters.h"
#import "react/renderer/components/RNRealtimeMarkdownSpec/Props.h"
#import "react/renderer/components/RNRealtimeMarkdownSpec/RCTComponentViewHelpers.h"

#import "RCTFabricComponentsPlugins.h"

using namespace facebook::react;

static NSString *RCTNSStringFromString(const std::string &string) {
    return [NSString stringWithUTF8String:string.c_str()];
}

static std::string RCTStringFromNSString(NSString *string) {
    return string.UTF8String ?: "";
}

@interface RealtimeMarkdownView () <RCTRealtimeMarkdownViewViewProtocol, UITextViewDelegate>
@end

@implementation RealtimeMarkdownView {
    UITextView * _textView;
    NSMutableAttributedString *_attributedText;
    BOOL _needsInitialSizeNotification;
    NSMutableArray<UILabel *> *_hashtagLabels;
    NSMutableArray<UILabel *> *_bulletLabels;
}

+ (ComponentDescriptorProvider)componentDescriptorProvider
{
    return concreteComponentDescriptorProvider<RealtimeMarkdownViewComponentDescriptor>();
}

- (instancetype)initWithFrame:(CGRect)frame
{
    if (self = [super initWithFrame:frame]) {
        _needsInitialSizeNotification = YES;
        _hashtagLabels = [NSMutableArray array];
        _bulletLabels = [NSMutableArray array];
        
        _textView = [[UITextView alloc] initWithFrame:self.bounds];
        _textView.delegate = self;
        _textView.autocorrectionType = UITextAutocorrectionTypeNo;
        _textView.backgroundColor = [UIColor clearColor];
        _textView.scrollEnabled = YES;
        _textView.alwaysBounceVertical = NO;
        _textView.bounces = NO;
        
        _textView.textContainer.lineFragmentPadding = 0;
        _textView.textContainerInset = UIEdgeInsetsMake(0, 8, 0, 0);

        self.contentView = _textView;
        
        // Make text view resize with parent view
        _textView.translatesAutoresizingMaskIntoConstraints = NO;
        [NSLayoutConstraint activateConstraints:@[
            [_textView.topAnchor constraintEqualToAnchor:self.topAnchor],
            [_textView.leadingAnchor constraintEqualToAnchor:self.leadingAnchor],
            [_textView.trailingAnchor constraintEqualToAnchor:self.trailingAnchor],
            [_textView.bottomAnchor constraintEqualToAnchor:self.bottomAnchor]
        ]];
        
        // Without this sometimes first render is with scroll bar visible (not correct contentSize is communicated to react native)
        _textView.layoutManager.allowsNonContiguousLayout = NO;
        
        // Apply initial markdown styling
        [self applyMarkdownStyling];
    }
    return self;
}

- (void)updateProps:(Props::Shared const &)props oldProps:(Props::Shared const &)oldProps
{
    const auto &oldViewProps = *std::static_pointer_cast<RealtimeMarkdownViewProps const>(_props);
    const auto &newViewProps = *std::static_pointer_cast<RealtimeMarkdownViewProps const>(props);

    if (oldViewProps.text != newViewProps.text) {
        _textView.text = RCTNSStringFromString(newViewProps.text);
        [self applyMarkdownStyling];
    }

    if (oldViewProps.fontFamily != newViewProps.fontFamily) {
        _textView.font = [UIFont fontWithName:RCTNSStringFromString(newViewProps.fontFamily) size:18.0];
        [self applyMarkdownStyling];
    }

    [super updateProps:props oldProps:oldProps];
}

- (void)updateEventEmitter:(facebook::react::SharedEventEmitter)eventEmitter
{
    [super updateEventEmitter:eventEmitter];
    
    // Check if we need to send initial size notification
    if (_needsInitialSizeNotification && eventEmitter) {
        _needsInitialSizeNotification = NO;
        [self notifyPossibleContentSizeChange];
    }
}

- (void)notifyPossibleContentSizeChange
{
    if (_eventEmitter) {
        std::dynamic_pointer_cast<const RealtimeMarkdownViewEventEmitter>(_eventEmitter)
            ->onContentSizeChange(RealtimeMarkdownViewEventEmitter::OnContentSizeChange{
                .height = static_cast<double>(_textView.contentSize.height)
            });
    }
}

- (BOOL)textView:(UITextView *)textView shouldChangeTextInRange:(NSRange)range replacementText:(NSString *)text {
    if ([text isEqualToString:@"\n"]) {
        NSString *currentText = textView.text;
        NSRange lineRange = [currentText lineRangeForRange:range];
        NSString *currentLine = [currentText substringWithRange:lineRange];
        
        // Updated regex to match bullet points with optional spaces (first level has no spaces)
        NSRegularExpression *bulletRegex = [NSRegularExpression regularExpressionWithPattern:@"^(  )*- " options:0 error:nil];
        NSTextCheckingResult *match = [bulletRegex firstMatchInString:currentLine options:0 range:NSMakeRange(0, currentLine.length)];
        
        if (match) {
            // Get the full matched range to determine indentation
            NSRange fullRange = [match range];
            NSString *indentation = fullRange.length > 2 ? [currentLine substringWithRange:NSMakeRange(0, fullRange.length - 2)] : @"";
            NSString *bulletWithIndent = [NSString stringWithFormat:@"%@- ", indentation];
            
            // If the current line only contains an indented bullet point and spaces, remove it
            if ([currentLine isEqualToString:bulletWithIndent]) {
                textView.text = [currentText stringByReplacingCharactersInRange:lineRange withString:@"\n"];
                return NO;
            }
            
            // Insert a new bullet point with the same indentation
            textView.text = [currentText stringByReplacingCharactersInRange:range withString:[@"\n" stringByAppendingString:bulletWithIndent]];
            
            // Update styling
            [self applyMarkdownStyling];
            
            // Move cursor to after the new bullet point
            textView.selectedRange = NSMakeRange(range.location + 3 + indentation.length, 0);
            
            return NO;
        }
    }
    
    return YES;
}

- (void)textViewDidChange:(UITextView *)textView
{
    // Notify React Native about text change
    if (_eventEmitter) {
        std::dynamic_pointer_cast<const RealtimeMarkdownViewEventEmitter>(_eventEmitter)
            ->onTextChange(RealtimeMarkdownViewEventEmitter::OnTextChange{
                .text = RCTStringFromNSString(textView.text)
            });
    }
    
    [self applyMarkdownStyling];
    [self notifyPossibleContentSizeChange];
}

- (NSMutableParagraphStyle *)bulletStyleForIndentLevel:(NSUInteger)indentLevel
{
    NSMutableParagraphStyle *bulletStyle = [[NSMutableParagraphStyle alloc] init];
    CGFloat baseIndent = 20.0 + (indentLevel * 20.0);
    bulletStyle.firstLineHeadIndent = baseIndent;
    bulletStyle.headIndent = baseIndent;
    bulletStyle.paragraphSpacingBefore = 8.0; // Space before paragraph
    return bulletStyle;
}

- (void)applyMarkdownStyling
{
    // Remove existing labels
    for (UILabel *label in _hashtagLabels) {
        [label removeFromSuperview];
    }
    [_hashtagLabels removeAllObjects];
    
    for (UILabel *label in _bulletLabels) {
        [label removeFromSuperview];
    }
    [_bulletLabels removeAllObjects];
    
    NSString *text = _textView.text;
    _attributedText = [[NSMutableAttributedString alloc] initWithString:text];
    
    // Define text attributes
    UIFont *baseFont = [UIFont systemFontOfSize:18];
    UIFont *normalFont = baseFont;
    UIFont *headingFont = [UIFont fontWithDescriptor:[[baseFont fontDescriptor] fontDescriptorWithSymbolicTraits:UIFontDescriptorTraitBold] size:24];
    
    // Create default paragraph style with standard spacing
    NSMutableParagraphStyle *defaultStyle = [[NSMutableParagraphStyle alloc] init];
    defaultStyle.paragraphSpacingBefore = 8.0;
    
    // Apply normal font and default paragraph style to all text first
    [_attributedText addAttribute:NSFontAttributeName value:normalFont range:NSMakeRange(0, text.length)];
    [_attributedText addAttribute:NSParagraphStyleAttributeName value:defaultStyle range:NSMakeRange(0, text.length)];

    __block NSUInteger lineStart = 0;
    [text enumerateSubstringsInRange:NSMakeRange(0, text.length)
                            options:NSStringEnumerationByLines
                         usingBlock:^(NSString *line, NSRange substringRange, NSRange enclosingRange, BOOL *stop) {
        // Heading with increased vertical spacing
        if ([line hasPrefix:@"# "]) {
            NSMutableParagraphStyle *headingStyle = [[NSMutableParagraphStyle alloc] init];
            headingStyle.paragraphSpacingBefore = 16.0;
            headingStyle.paragraphSpacing = 8.0;
            
            [self->_attributedText addAttribute:NSParagraphStyleAttributeName value:headingStyle range:enclosingRange];
            
            // Hide the "# " marker in text
            NSRange markerRange = NSMakeRange(substringRange.location, 2);
            [self->_attributedText addAttribute:NSForegroundColorAttributeName value:[UIColor clearColor] range:markerRange];
            [self->_attributedText addAttribute:NSKernAttributeName value:@(-10.0) range:markerRange];
            
            [self->_attributedText addAttribute:NSFontAttributeName value:headingFont range:NSMakeRange(enclosingRange.location + 2, enclosingRange.length - 2)];
            
            // Create and position hashtag label
            UILabel *hashtagLabel = [[UILabel alloc] init];
            hashtagLabel.text = @"#";
            hashtagLabel.font = headingFont;
            hashtagLabel.textColor = [UIColor systemGrayColor];
            [hashtagLabel sizeToFit];
            
            // Position will be set in layoutSubviews
            [self addSubview:hashtagLabel];
            [self->_hashtagLabels addObject:hashtagLabel];
        }
        
        // Bullet points with indentation levels
        NSRegularExpression *bulletRegex = [NSRegularExpression regularExpressionWithPattern:@"^(  )*- " options:0 error:nil];
        NSTextCheckingResult *bulletMatch = [bulletRegex firstMatchInString:line options:0 range:NSMakeRange(0, line.length)];
        
        if (bulletMatch) {
            // Get the full matched range to determine indentation level
            NSRange fullRange = [bulletMatch range];
            NSUInteger indentLevel = (fullRange.length - 2) / 2; // Subtract 2 for "- " and divide by 2 for space pairs
            
            // Hide the bullet marker
            [self->_attributedText addAttribute:NSForegroundColorAttributeName value:[UIColor clearColor] range:NSMakeRange(substringRange.location, fullRange.length)];
            [self->_attributedText addAttribute:NSKernAttributeName value:@(-10.0) range:NSMakeRange(substringRange.location, fullRange.length)];
            
            [self->_attributedText addAttribute:NSParagraphStyleAttributeName 
                                       value:[self bulletStyleForIndentLevel:indentLevel] 
                                       range:enclosingRange];
            
            // Create and position bullet label
            UILabel *bulletLabel = [[UILabel alloc] init];
            bulletLabel.font = [UIFont systemFontOfSize:18];
            bulletLabel.textColor = [UIColor blackColor];
            
            // Set bullet symbol based on indent level
            if (indentLevel == 0) {
                bulletLabel.text = @"•";      // U+2022: Standard bullet, but we'll adjust the size
                bulletLabel.font = [UIFont systemFontOfSize:26];  // Slightly larger for better visibility
            } else if (indentLevel == 1) {
                bulletLabel.text = @"◦";      // U+25E6: White bullet, more balanced than "○"
                bulletLabel.font = [UIFont systemFontOfSize:28];
            } else {
                bulletLabel.text = @"—";      // Keeping the existing dash for third level
                bulletLabel.font = [UIFont systemFontOfSize:16];
            }
            
            [bulletLabel sizeToFit];
            [self addSubview:bulletLabel];
            [self->_bulletLabels addObject:bulletLabel];
        }
        
        lineStart = enclosingRange.location + enclosingRange.length;
    }];
    
    // Bold (**text**)
    NSRegularExpression *boldRegex = [NSRegularExpression regularExpressionWithPattern:@"\\*\\*(.*?)\\*\\*" options:0 error:nil];
    [boldRegex enumerateMatchesInString:text options:0 range:NSMakeRange(0, text.length) usingBlock:^(NSTextCheckingResult *match, NSMatchingFlags flags, BOOL *stop) {
        // Hide the ** markers by making them zero-sized and invisible
        NSRange fullRange = [match range];
        NSRange startMarkerRange = NSMakeRange(fullRange.location, 2);
        NSRange endMarkerRange = NSMakeRange(fullRange.location + fullRange.length - 2, 2);
        
        // Make markers invisible and zero-sized
        [self->_attributedText addAttribute:NSForegroundColorAttributeName value:[UIColor clearColor] range:startMarkerRange];
        [self->_attributedText addAttribute:NSForegroundColorAttributeName value:[UIColor clearColor] range:endMarkerRange];
        [self->_attributedText addAttribute:NSFontAttributeName value:[UIFont systemFontOfSize:0] range:startMarkerRange];
        [self->_attributedText addAttribute:NSFontAttributeName value:[UIFont systemFontOfSize:0] range:endMarkerRange];

        // Make the content bold using the custom font
        NSRange contentRange = [match rangeAtIndex:1];
        UIFont *boldFont = [UIFont fontWithDescriptor:[[baseFont fontDescriptor] fontDescriptorWithSymbolicTraits:UIFontDescriptorTraitBold] size:baseFont.pointSize];
        [self->_attributedText addAttribute:NSFontAttributeName value:boldFont range:contentRange];
    }];
    
    // Italic (__text__)
    NSRegularExpression *italicRegex = [NSRegularExpression regularExpressionWithPattern:@"__(.*?)__" options:0 error:nil];
    [italicRegex enumerateMatchesInString:text options:0 range:NSMakeRange(0, text.length) usingBlock:^(NSTextCheckingResult *match, NSMatchingFlags flags, BOOL *stop) {
        // Hide the __ markers by making them zero-sized and invisible
        NSRange fullRange = [match range];
        NSRange startMarkerRange = NSMakeRange(fullRange.location, 2);
        NSRange endMarkerRange = NSMakeRange(fullRange.location + fullRange.length - 2, 2);
        
        // Make markers invisible and zero-sized
        [self->_attributedText addAttribute:NSForegroundColorAttributeName value:[UIColor clearColor] range:startMarkerRange];
        [self->_attributedText addAttribute:NSForegroundColorAttributeName value:[UIColor clearColor] range:endMarkerRange];
        [self->_attributedText addAttribute:NSFontAttributeName value:[UIFont systemFontOfSize:0] range:startMarkerRange];
        [self->_attributedText addAttribute:NSFontAttributeName value:[UIFont systemFontOfSize:0] range:endMarkerRange];

        // Make the content italic using the custom font
        NSRange contentRange = [match rangeAtIndex:1];
        UIFont *italicFont = [UIFont fontWithDescriptor:[[baseFont fontDescriptor] fontDescriptorWithSymbolicTraits:UIFontDescriptorTraitItalic] size:baseFont.pointSize];
        [self->_attributedText addAttribute:NSFontAttributeName value:italicFont range:contentRange];
    }];
    
    // Apply the styled text while maintaining cursor position
    NSRange selectedRange = _textView.selectedRange;
    _textView.attributedText = _attributedText;
    _textView.selectedRange = selectedRange;
    
    // Force immediate layout
    [_textView layoutIfNeeded];
    
    [self setNeedsLayout];
}

- (void)layoutSubviews
{
    [super layoutSubviews];
    
    // Position hashtag labels
    NSString *text = _textView.text;
    __block NSUInteger labelIndex = 0;
    
    [text enumerateSubstringsInRange:NSMakeRange(0, text.length)
                            options:NSStringEnumerationByLines
                         usingBlock:^(NSString *line, NSRange substringRange, NSRange enclosingRange, BOOL *stop) {
            if ([line hasPrefix:@"# "]) {
                if (labelIndex < self->_hashtagLabels.count) {
                    UILabel *hashtagLabel = self->_hashtagLabels[labelIndex];
                    CGRect lineRect = [self->_textView.layoutManager lineFragmentUsedRectForGlyphAtIndex:substringRange.location effectiveRange:NULL];
                    hashtagLabel.frame = CGRectMake(-16, 
                                                  lineRect.origin.y + self->_textView.textContainerInset.top,
                                                  20.0,
                                                  lineRect.size.height);
                    labelIndex++;
                }
            }
        }];
    
    // Position bullet labels
    __block NSUInteger bulletLabelIndex = 0;
    
    [text enumerateSubstringsInRange:NSMakeRange(0, text.length)
                            options:NSStringEnumerationByLines
                         usingBlock:^(NSString *line, NSRange substringRange, NSRange enclosingRange, BOOL *stop) {
        // Update bullet regex to handle first level without spaces
        NSRegularExpression *bulletRegex = [NSRegularExpression regularExpressionWithPattern:@"^(  )*- " options:0 error:nil];
        NSTextCheckingResult *bulletMatch = [bulletRegex firstMatchInString:line options:0 range:NSMakeRange(0, line.length)];
        
        if (bulletMatch && bulletLabelIndex < self->_bulletLabels.count) {
            UILabel *bulletLabel = self->_bulletLabels[bulletLabelIndex];
            CGRect lineRect = [self->_textView.layoutManager lineFragmentUsedRectForGlyphAtIndex:substringRange.location effectiveRange:NULL];
            
            // Calculate indent level based on full match length
            NSRange fullRange = [bulletMatch range];
            NSUInteger indentLevel = (fullRange.length - 2) / 2; // Subtract 2 for "- " and divide by 2 for space pairs
            CGFloat xOffset = 8 + (indentLevel * 20.0);
            
            bulletLabel.frame = CGRectMake(xOffset,
                                         lineRect.origin.y + self->_textView.textContainerInset.top,
                                         20.0,
                                         lineRect.size.height);
            bulletLabelIndex++;
        }
    }];
    
    [self notifyPossibleContentSizeChange];
}

Class<RCTComponentViewProtocol> RealtimeMarkdownViewCls(void)
{
    return RealtimeMarkdownView.class;
}
@end
