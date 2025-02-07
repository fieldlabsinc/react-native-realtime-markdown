import React from "react";
import { StyleSheet, TextProps } from "react-native";
import RealtimeMarkdownViewNative from "./RealtimeMarkdownViewNativeComponent";

interface RealtimeMarkdownProps extends TextProps {
  color?: string;
  editable?: boolean;
  fontFamily?: string;
  children?: React.ReactNode;
  onTextChange?: (text: string) => void;
}

export function RealtimeMarkdown({
  children,
  style,
  fontFamily,
  onTextChange,
  ...props
}: RealtimeMarkdownProps) {
  const [height, setHeight] = React.useState<number | undefined>(undefined);
  const initialText = React.Children.toArray(children).join("");

  return (
    <RealtimeMarkdownViewNative
      {...props}
      text={initialText}
      fontFamily={fontFamily}
      style={[
        styles.textView,
        {
          minHeight: height ? height + 30 : undefined,
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
