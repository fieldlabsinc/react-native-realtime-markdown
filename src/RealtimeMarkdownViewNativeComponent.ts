import type { ViewProps } from "react-native";
import type {
  DirectEventHandler,
  Double,
} from "react-native/Libraries/Types/CodegenTypes";
import codegenNativeComponent from "react-native/Libraries/Utilities/codegenNativeComponent";

interface NativeProps extends ViewProps {
  color?: string;
  text?: string;
  editable?: boolean;
  fontFamily?: string;
  disabled?: boolean;

  onContentSizeChange?: DirectEventHandler<{
    height: Double;
  }>;
  onTextChange?: DirectEventHandler<{
    text: string;
  }>;
}

export default codegenNativeComponent<NativeProps>("RealtimeMarkdownView");
