#import <UIKit/UIKit.h>
#import "DrawingTypes.h"
#import "DrawingText.h" // Import the new text model

@class DrawingView;

NS_ASSUME_NONNULL_BEGIN

/**
 * @protocol DrawingViewDelegate
 * @brief 委托协议，用于在选中绘图项时通知外部。
 */
@protocol DrawingViewDelegate <NSObject>
- (void)drawingView:(DrawingView *)drawingView didSelectItem:(nullable id)item;
@end

/**
 * @class DrawingView
 * @brief 负责处理所有绘图操作的视图，包括触摸事件、图形渲染和状态管理。
 */
@interface DrawingView : UIView

// 委托
@property (nonatomic, weak, nullable) id<DrawingViewDelegate> delegate;

// 绘图属性
@property (nonatomic, assign) DrawingToolType currentTool;
@property (nonatomic, strong) UIColor *strokeColor;
@property (nonatomic, strong, nullable) UIColor *fillColor; // 新增填充颜色
@property (nonatomic, assign) CGFloat lineWidth;
@property (nonatomic, copy, nullable) NSArray<NSNumber *> *lineDashPattern; // 新增：虚线样式
@property (nonatomic, assign) CGFloat fontSize; // 新增：字体大小

// 绘图状态
@property (nonatomic, strong, nullable) id selectedItem; // 当前选中的对象
@property (nonatomic, readonly) BOOL canUndo;
@property (nonatomic, readonly) BOOL canRedo;

// 公共方法
- (void)undo;
- (void)redo;
- (void)clearDrawing;
- (void)restoreAllDrawing; // 新增：还原所有绘图
- (UIImage *)captureImage;

// 属性编辑
- (void)updateSelectedStrokeColor:(UIColor *)color;
- (void)updateSelectedFillColor:(nullable UIColor *)color;
- (void)updateSelectedLineWidth:(CGFloat)lineWidth;
- (void)updateSelectedLineDashPattern:(nullable NSArray<NSNumber *> *)pattern;

// 获取绘图数据
- (NSArray *)getDrawnItems;

// 坐标变换方法
- (void)transformDrawnItemsFromSize:(CGSize)oldSize toSize:(CGSize)newSize;

@end

NS_ASSUME_NONNULL_END