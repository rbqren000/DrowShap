#import <UIKit/UIKit.h>
#import "DrawingTypes.h"

@class DrawingBoardView;

NS_ASSUME_NONNULL_BEGIN

/**
 * @protocol DrawingBoardViewDelegate
 * @brief 委托协议，用于在选中绘图项时通知外部控制器。
 */
@protocol DrawingBoardViewDelegate <NSObject>
- (void)drawingBoardView:(DrawingBoardView *)boardView didSelectItem:(nullable id)item;
@end

/**
 * @class DrawingBoardView
 * @brief 封装了绘图和缩放功能的主组件。
 *
 * 该视图集成了一个 UIScrollView 用于图像缩放，一个 UIImageView 用于显示图像，
 * 以及一个 DrawingView 用于在图像上进行绘制。它提供了统一的接口来控制
 * 绘图工具、颜色、线宽，并管理撤销/重做操作。
 */
@interface DrawingBoardView : UIView

// 委托
@property (nonatomic, weak, nullable) id<DrawingBoardViewDelegate> delegate;

// 绘图相关属性
@property (nonatomic, assign) DrawingToolType currentTool;
@property (nonatomic, strong) UIColor *strokeColor;
@property (nonatomic, strong, nullable) UIColor *fillColor;
@property (nonatomic, assign) CGFloat lineWidth;
@property (nonatomic, copy, nullable) NSArray<NSNumber *> *lineDashPattern;
@property (nonatomic, assign) CGFloat fontSize;

// 状态控制
@property (nonatomic, assign, getter=isZoomEnabled) BOOL zoomEnabled; // 控制是否允许缩放
@property (nonatomic, readonly) BOOL canUndo;
@property (nonatomic, readonly) BOOL canRedo;

/**
 * @brief 设置要绘制的背景图片。
 * @param image 要显示的图片。
 */
- (void)setupWithImage:(UIImage *)image;

/**
 * @brief 撤销上一步操作。
 */
- (void)undo;

/**
 * @brief 重做上一步被撤销的操作。
 */
- (void)redo;

/**
 * @brief 清除所有绘图。
 */
- (void)clearDrawing;

/**
 * @brief 还原所有被清空的绘图。
 */
- (void)restoreAllDrawing;

/**
 * @brief 获取当前绘制结果的图片。
 * @return 包含背景图和所有绘制内容的 UIImage。
 */
- (UIImage *)captureDrawing;

/**
 * @brief 获取与背景图片原始尺寸一致的绘制结果图片。
 * @discussion 该方法不使用设备屏幕密度进行倍图处理，直接基于背景图片的原始尺寸生成图片，
 *            确保输出图片尺寸与背景图片完全一致。绘图内容会按比例缩放到原始图片尺寸。
 * @return 与背景图片尺寸一致的 UIImage，如果没有背景图片则返回 nil。
 */
- (UIImage *)captureDrawingWithOriginalSize;

@end

NS_ASSUME_NONNULL_END