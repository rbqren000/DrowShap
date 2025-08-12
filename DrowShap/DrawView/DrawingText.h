#import <UIKit/UIKit.h>

NS_ASSUME_NONNULL_BEGIN

/**
 * @class DrawingText
 * @brief 存储单个文本块的属性，包括文本内容、位置和富文本属性。
 */
@interface DrawingText : NSObject

@property (nonatomic, copy) NSString *text;
@property (nonatomic, assign) CGPoint origin;
@property (nonatomic, copy) NSDictionary<NSAttributedStringKey, id> *attributes;

// 计算文本所占的矩形区域
- (CGRect)boundingRect;

+ (instancetype)text:(NSString *)text
            atOrigin:(CGPoint)origin
      withAttributes:(NSDictionary<NSAttributedStringKey, id> *)attributes;

@end

NS_ASSUME_NONNULL_END