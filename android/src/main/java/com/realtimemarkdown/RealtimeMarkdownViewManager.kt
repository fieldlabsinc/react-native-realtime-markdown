package com.realtimemarkdown

import android.graphics.Color
import com.facebook.react.module.annotations.ReactModule
import com.facebook.react.uimanager.SimpleViewManager
import com.facebook.react.uimanager.ThemedReactContext
import com.facebook.react.uimanager.ViewManagerDelegate
import com.facebook.react.uimanager.annotations.ReactProp
import com.facebook.react.viewmanagers.RealtimeMarkdownViewManagerInterface
import com.facebook.react.viewmanagers.RealtimeMarkdownViewManagerDelegate

@ReactModule(name = RealtimeMarkdownViewManager.NAME)
class RealtimeMarkdownViewManager : SimpleViewManager<RealtimeMarkdownView>(),
  RealtimeMarkdownViewManagerInterface<RealtimeMarkdownView> {
  private val mDelegate: ViewManagerDelegate<RealtimeMarkdownView>

  init {
    mDelegate = RealtimeMarkdownViewManagerDelegate(this)
  }

  override fun getDelegate(): ViewManagerDelegate<RealtimeMarkdownView>? {
    return mDelegate
  }

  override fun getName(): String {
    return NAME
  }

  public override fun createViewInstance(context: ThemedReactContext): RealtimeMarkdownView {
    return RealtimeMarkdownView(context)
  }

  @ReactProp(name = "color")
  override fun setColor(view: RealtimeMarkdownView?, color: String?) {
    view?.setBackgroundColor(Color.parseColor(color))
  }

  @ReactProp(name = "text")
  override fun setText(view: RealtimeMarkdownView?, value: String?) {
    // Implement text setting logic here
    // For now this is a stub implementation
  }

  @ReactProp(name = "editable")
  override fun setEditable(view: RealtimeMarkdownView?, value: Boolean) {
    // Implement editable setting logic here
    // For now this is a stub implementation
  }

  @ReactProp(name = "fontFamily")
  override fun setFontFamily(view: RealtimeMarkdownView?, value: String?) {
    // Implement font family setting logic here
    // For now this can be a stub implementation
  }

  companion object {
    const val NAME = "RealtimeMarkdownView"
  }
}
