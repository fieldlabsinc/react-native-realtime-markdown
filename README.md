# react-native-realtime-markdown

A React Native component for real-time markdown editing.

## Installation

```bash
npm install react-native-realtime-markdown
```

## Usage

```javascript
import { RealtimeMarkdown } from "react-native-realtime-markdown";

<RealtimeMarkdown># Hello, world!</RealtimeMarkdown>;
```

Also add this to AppDelegate.mm

```
#import "RealtimeMarkdownView.h"

- (NSDictionary<NSString *,Class<RCTComponentViewProtocol>> *)thirdPartyFabricComponents
{
  NSMutableDictionary * dictionary = [super thirdPartyFabricComponents].mutableCopy;
  dictionary[@"RealtimeMarkdownView"] = [RealtimeMarkdownView class];
  return dictionary;
}
```
