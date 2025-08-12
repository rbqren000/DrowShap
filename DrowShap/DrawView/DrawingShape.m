#import "DrawingShape.h"

@implementation DrawingShape

#pragma mark - NSSecureCoding

+ (BOOL)supportsSecureCoding {
    return YES;
}

- (void)encodeWithCoder:(NSCoder *)coder {
    [coder encodeObject:self.path forKey:@"path"];
    [coder encodeObject:self.strokeColor forKey:@"strokeColor"];
    [coder encodeObject:self.fillColor forKey:@"fillColor"];
    [coder encodeDouble:self.lineWidth forKey:@"lineWidth"];
    [coder encodeObject:self.lineDashPattern forKey:@"lineDashPattern"];
    [coder encodeCGRect:self.frame forKey:@"frame"];
}

- (instancetype)initWithCoder:(NSCoder *)coder {
    self = [super init];
    if (self) {
        _path = [coder decodeObjectOfClass:[UIBezierPath class] forKey:@"path"];
        _strokeColor = [coder decodeObjectOfClass:[UIColor class] forKey:@"strokeColor"];
        _fillColor = [coder decodeObjectOfClass:[UIColor class] forKey:@"fillColor"];
        _lineWidth = [coder decodeDoubleForKey:@"lineWidth"];
        // 安全解码数组，指定允许的类
        _lineDashPattern = [coder decodeObjectOfClasses:[NSSet setWithObjects:[NSArray class], [NSNumber class], nil] forKey:@"lineDashPattern"];
        _frame = [coder decodeCGRectForKey:@"frame"];
    }
    return self;
}

#pragma mark - NSCopying

- (id)copyWithZone:(NSZone *)zone {
    // 创建一个新的实例，并深拷贝所有属性
    DrawingShape *copy = [[DrawingShape allocWithZone:zone] init];
    copy.path = [self.path copy]; // UIBezierPath 支持 copy
    copy.strokeColor = self.strokeColor; // UIColor 是不可变的，可以直接赋值
    copy.fillColor = self.fillColor;
    copy.lineWidth = self.lineWidth;
    copy.lineDashPattern = [self.lineDashPattern copy]; // NSArray 支持 copy
    copy.frame = self.frame; // 复制frame
    return copy;
}

#pragma mark - Initialization

+ (instancetype)shapeWithPath:(UIBezierPath *)path
                  strokeColor:(UIColor *)strokeColor
                    fillColor:(nullable UIColor *)fillColor
                    lineWidth:(CGFloat)lineWidth
              lineDashPattern:(nullable NSArray<NSNumber *> *)lineDashPattern {
    DrawingShape *shape = [[self alloc] init];
    shape.path = path;
    shape.strokeColor = strokeColor;
    shape.fillColor = fillColor;
    shape.lineWidth = lineWidth;
    shape.lineDashPattern = lineDashPattern;
    [shape updateFrame]; // 初始化时计算frame
    return shape;
}

#pragma mark - Frame Management

- (void)updateFrame {
    if (!self.path) {
        self.frame = CGRectZero;
        return;
    }
    
    // 获取路径的基础边界框
    CGRect pathBounds = self.path.bounds;
    
    // 考虑线宽的影响，扩展边界框
    CGFloat halfLineWidth = self.lineWidth / 2.0;
    self.frame = CGRectInset(pathBounds, -halfLineWidth, -halfLineWidth);
}

// 重写path的setter，自动更新frame
- (void)setPath:(UIBezierPath *)path {
    _path = path;
    [self updateFrame];
}

// 重写lineWidth的setter，自动更新frame
- (void)setLineWidth:(CGFloat)lineWidth {
    _lineWidth = lineWidth;
    [self updateFrame];
}

@end
