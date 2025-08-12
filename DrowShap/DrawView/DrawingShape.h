#import <UIKit/UIKit.h>

NS_ASSUME_NONNULL_BEGIN

/**
 * @class DrawingShape
 * @brief 存储单个绘制图形的属性，包括路径、颜色和线宽。
 */
@interface DrawingShape : NSObject <NSCopying, NSSecureCoding>

@property (nonatomic, strong) UIBezierPath *path;
@property (nonatomic, strong) UIColor *strokeColor; // 重命名 color 为 strokeColor，更清晰
@property (nonatomic, strong, nullable) UIColor *fillColor; // 新增填充颜色，可以为nil
@property (nonatomic, assign) CGFloat lineWidth;
@property (nonatomic, copy, nullable) NSArray<NSNumber *> *lineDashPattern; // 新增：虚线样式
 @property (nonatomic, assign) CGRect frame; // 新增：精确记录图形的边界框，包含线宽

+ (instancetype)shapeWithPath:(UIBezierPath *)path
                  strokeColor:(UIColor *)strokeColor
                    fillColor:(nullable UIColor *)fillColor
                    lineWidth:(CGFloat)lineWidth
              lineDashPattern:(nullable NSArray<NSNumber *> *)lineDashPattern;

// 更新frame的方法
- (void)updateFrame;

@end

NS_ASSUME_NONNULL_END
