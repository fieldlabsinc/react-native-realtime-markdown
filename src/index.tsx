import React, { useEffect } from "react";
import { StyleSheet, TextProps } from "react-native";
import RealtimeMarkdownViewNative from "./RealtimeMarkdownViewNativeComponent";

interface RealtimeMarkdownProps extends TextProps {
  color?: string;
  editable?: boolean;
  fontFamily?: string;
  children?: React.ReactNode;
  onTextChange?: (text: string) => void;
  disabled?: boolean;
}

export function RealtimeMarkdown({
  children,
  style,
  fontFamily,
  onTextChange,
  disabled,
  ...props
}: RealtimeMarkdownProps) {
  const [height, setHeight] = React.useState<number | undefined>(undefined);
  const initialTextRef = React.useRef(
    React.Children.toArray(children).join("")
  );

  // Update initialTextRef when children changes and component is disabled
  useEffect(() => {
    if (disabled) {
      initialTextRef.current = React.Children.toArray(children).join("");
    }
  }, [children, disabled]);

  // This is a hack, monkey patch to fix that long text wouldn't cause layout shifts when the text is long and onContentSizeChange did not come from the native side yet.
  useEffect(() => {
    const lineCount = initialTextRef.current.split("\n").length;
    if (lineCount > 8) {
      setHeight(500);
    }
  }, []);

  return (
    <RealtimeMarkdownViewNative
      {...props}
      text={initialTextRef.current}
      fontFamily={fontFamily}
      disabled={disabled}
      style={[
        styles.textView,
        {
          minHeight: height ? height + (disabled ? 200 : 30) : undefined, // disabled = it might be streaming. So we need more height to avoid content starting to be scrollable for a moment
        },
        style,
      ]}
      onContentSizeChange={({ nativeEvent: { height: newHeight } }) => {
        setHeight(newHeight);
      }}
      onTextChange={({ nativeEvent: { text: newText } }) => {
        onTextChange?.(newText);
      }}
    />
  );
}

const styles = StyleSheet.create({
  textView: {
    marginTop: 10,
  },
});
