#import "DrawingText.h"

@implementation DrawingText

#pragma mark - NSSecureCoding

+ (BOOL)supportsSecureCoding {
    return YES;
}

- (void)encodeWithCoder:(NSCoder *)coder {
    [coder encodeObject:self.text forKey:@"text"];
    [coder encodeCGPoint:self.origin forKey:@"origin"];
    [coder encodeObject:self.attributes forKey:@"attributes"];
}

- (instancetype)initWithCoder:(NSCoder *)coder {
    self = [super init];
    if (self) {
        _text = [coder decodeObjectOfClass:[NSString class] forKey:@"text"];
        _origin = [coder decodeCGPointForKey:@"origin"];
        // 安全解码字典，指定允许的类
        NSSet *allowedClasses = [NSSet setWithObjects:[NSDictionary class], [NSString class], [UIFont class], [UIColor class], nil];
        _attributes = [coder decodeObjectOfClasses:allowedClasses forKey:@"attributes"];
    }
    return self;
}

#pragma mark - NSCopying

- (id)copyWithZone:(NSZone *)zone {
    DrawingText *copy = [[DrawingText allocWithZone:zone] init];
    copy.text = [self.text copy];
    copy.origin = self.origin; // CGPoint 是结构体，直接赋值就是复制
    copy.attributes = [self.attributes copy];
    return copy;
}

#pragma mark - Initialization

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