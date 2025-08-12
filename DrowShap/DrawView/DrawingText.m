#import "DrawingText.h"

@implementation DrawingText

+ (instancetype)text:(NSString *)text
            atOrigin:(CGPoint)origin
      withAttributes:(NSDictionary<NSAttributedStringKey, id> *)attributes {
    DrawingText *drawingText = [[self alloc] init];
    drawingText.text = text;
    drawingText.origin = origin;
    drawingText.attributes = attributes;
    return drawingText;
}

- (CGRect)boundingRect {
    if (!self.text || self.text.length == 0) {
        return CGRectZero;
    }
    // 计算文本在给定属性下所占的尺寸
    CGSize size = [self.text sizeWithAttributes:self.attributes];
    // 返回包含原点的矩形
    return CGRectMake(self.origin.x, self.origin.y, size.width, size.height);
}

@end