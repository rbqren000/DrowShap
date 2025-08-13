#import "DrawingBoardView.h"
#import "DrawingView.h"
#import "DrawingShape.h"
#import <CoreText/CoreText.h>

@interface DrawingBoardView () <UIScrollViewDelegate, DrawingViewDelegate>

@property (nonatomic, strong) UIScrollView *scrollView;
@property (nonatomic, strong) UIImageView *imageView;
@property (nonatomic, strong) DrawingView *drawingView;
// contentContainerView 将 imageView 和 drawingView 包裹起来，方便缩放
@property (nonatomic, strong) UIView *contentContainerView;

// 用于替换 layoutSubviews 中的 static 变量，避免多实例共享状态
@property (nonatomic, assign) CGSize lastBoundsSize;
@property (nonatomic, assign) BOOL initialSetupCompleted;

@end

@implementation DrawingBoardView

#pragma mark - Initialization

- (instancetype)initWithFrame:(CGRect)frame {
    self = [super initWithFrame:frame];
    if (self) {
        [self setupViews];
    }
    return self;
}

- (instancetype)initWithCoder:(NSCoder *)coder {
    self = [super initWithCoder:coder];
    if (self) {
        [self setupViews];
    }
    return self;
}

- (void)setupViews {
    // 1. 创建并配置 ScrollView
    self.scrollView = [[UIScrollView alloc] initWithFrame:self.bounds];
    self.scrollView.delegate = self;
    self.scrollView.maximumZoomScale = 3.0;
    self.scrollView.minimumZoomScale = 1.0;
    self.scrollView.showsVerticalScrollIndicator = NO;
    self.scrollView.showsHorizontalScrollIndicator = NO;
    self.scrollView.delaysContentTouches = NO; // 立即将触摸事件传递给内容视图
    self.scrollView.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
    [self addSubview:self.scrollView];

    // 2. 创建容器视图
    self.contentContainerView = [[UIView alloc] initWithFrame:self.bounds];
    [self.scrollView addSubview:self.contentContainerView];

    // 3. 创建 ImageView
    self.imageView = [[UIImageView alloc] initWithFrame:self.bounds];
    self.imageView.contentMode = UIViewContentModeScaleAspectFit;
    [self.contentContainerView addSubview:self.imageView];

    // 4. 创建 DrawingView
    self.drawingView = [[DrawingView alloc] initWithFrame:self.bounds];
    self.drawingView.delegate = self; // 设置委托
    [self.contentContainerView addSubview:self.drawingView];
    
    // 初始化状态
    _zoomEnabled = NO;
    _lastBoundsSize = CGSizeZero;
    _initialSetupCompleted = NO;
}

#pragma mark - DrawingViewDelegate

- (void)drawingView:(DrawingView *)drawingView didSelectItem:(id)item {
    if ([self.delegate respondsToSelector:@selector(drawingBoardView:didSelectItem:)]) {
        [self.delegate drawingBoardView:self didSelectItem:item];
    }
}

#pragma mark - Public Setup

- (void)setupWithImage:(UIImage *)image {
    // 记录旧图片尺寸（如果存在）
    CGSize oldImageSize = CGSizeZero;
    if (self.imageView.image) {
        oldImageSize = self.imageView.image.size;
    }
    
    // 设置新图片
    self.imageView.image = image;
    
    // 重置缩放和位置
    self.scrollView.zoomScale = 1.0;
    
    // 根据图片尺寸调整视图大小
    CGRect imageFrame = CGRectMake(0, 0, image.size.width, image.size.height);
    self.imageView.frame = imageFrame;
    self.drawingView.frame = imageFrame;
    self.contentContainerView.frame = imageFrame;
    self.scrollView.contentSize = image.size;
    
    // 如果有旧图片且尺寸不同，调整现有绘图数据的坐标
    if (!CGSizeEqualToSize(oldImageSize, CGSizeZero) && 
        !CGSizeEqualToSize(oldImageSize, image.size)) {
        [self.drawingView transformDrawnItemsFromSize:oldImageSize toSize:image.size];
    }
    
    [self updateMinZoomScaleForSize:self.bounds.size];
}

- (void)updateMinZoomScaleForSize:(CGSize)size {
    // 确保视图和图片的尺寸都大于零，以避免除以零的错误
    if (size.width <= 0 || size.height <= 0 || self.imageView.image == nil || self.imageView.image.size.width <= 0 || self.imageView.image.size.height <= 0) {
        self.scrollView.minimumZoomScale = 1.0;
        self.scrollView.zoomScale = 1.0;
        return;
    }
    
    CGFloat widthScale = size.width / self.imageView.image.size.width;
    CGFloat heightScale = size.height / self.imageView.image.size.height;
    CGFloat minScale = MIN(widthScale, heightScale);
    
    // 限制缩放范围，防止极端值
    minScale = MAX(0.1, MIN(minScale, 1.0)); // 最小10%，最大100%
    
    // 确保最大缩放比例合理
    CGFloat maxScale = MAX(3.0, minScale * 10.0); // 至少3倍，或最小缩放的10倍
    maxScale = MIN(maxScale, 10.0); // 但不超过10倍
    
    self.scrollView.minimumZoomScale = minScale;
    self.scrollView.maximumZoomScale = maxScale;
    self.scrollView.zoomScale = minScale;
    
    // 设置缩放后立即调整居中
    [self centerContentInScrollView];
}

- (void)centerContentInScrollView {
    CGSize boundsSize = self.scrollView.bounds.size;
    CGRect contentsFrame = self.contentContainerView.frame;
    
    if (contentsFrame.size.width < boundsSize.width) {
        contentsFrame.origin.x = (boundsSize.width - contentsFrame.size.width) / 2.0;
    } else {
        contentsFrame.origin.x = 0.0;
    }
    
    if (contentsFrame.size.height < boundsSize.height) {
        contentsFrame.origin.y = (boundsSize.height - contentsFrame.size.height) / 2.0;
    } else {
        contentsFrame.origin.y = 0.0;
    }
    
    self.contentContainerView.frame = contentsFrame;
}

- (void)layoutSubviews {
    [super layoutSubviews];
    
    // 只有在视图尺寸发生变化时才更新缩放比例，避免不必要的计算
    if (!CGSizeEqualToSize(self.bounds.size, self.lastBoundsSize)) {
        [self updateMinZoomScaleForSize:self.bounds.size];
        self.lastBoundsSize = self.bounds.size;
    }
    
    // 确保在视图完全加载后设置正确的初始状态
    if (!self.initialSetupCompleted && self.scrollView.pinchGestureRecognizer) {
        // 现在手势识别器已经准备好，可以安全地设置初始状态
        [self setZoomEnabled:_zoomEnabled];
        self.initialSetupCompleted = YES;
    }
}

#pragma mark - UIScrollViewDelegate

- (UIView *)viewForZoomingInScrollView:(UIScrollView *)scrollView {
    return self.contentContainerView;
}

- (void)scrollViewDidZoom:(UIScrollView *)scrollView {
    [self centerContentInScrollView];
}

- (void)scrollViewDidEndZooming:(UIScrollView *)scrollView withView:(UIView *)view atScale:(CGFloat)scale {
    [self centerContentInScrollView];
}

#pragma mark - Property Forwarding

- (void)setCurrentTool:(DrawingToolType)currentTool {
    self.drawingView.currentTool = currentTool;
}

- (DrawingToolType)currentTool {
    return self.drawingView.currentTool;
}

- (void)setStrokeColor:(UIColor *)strokeColor {
    self.drawingView.strokeColor = strokeColor;
}

- (UIColor *)strokeColor {
    return self.drawingView.strokeColor;
}

- (void)setFillColor:(UIColor *)fillColor {
    self.drawingView.fillColor = fillColor;
}

- (UIColor *)fillColor {
    return self.drawingView.fillColor;
}

- (void)setLineDashPattern:(NSArray<NSNumber *> *)lineDashPattern {
    self.drawingView.lineDashPattern = lineDashPattern;
}

- (NSArray<NSNumber *> *)lineDashPattern {
    return self.drawingView.lineDashPattern;
}

- (void)setFontSize:(CGFloat)fontSize {
    self.drawingView.fontSize = fontSize;
}

- (CGFloat)fontSize {
    return self.drawingView.fontSize;
}

- (void)setLineWidth:(CGFloat)lineWidth {
    self.drawingView.lineWidth = lineWidth;
}

- (CGFloat)lineWidth {
    return self.drawingView.lineWidth;
}

- (BOOL)canUndo {
    return self.drawingView.canUndo;
}

- (BOOL)canRedo {
    return self.drawingView.canRedo;
}

- (void)setZoomEnabled:(BOOL)zoomEnabled {
    _zoomEnabled = zoomEnabled;
    // 控制是否可以滚动
    self.scrollView.scrollEnabled = zoomEnabled;
    // 通过禁用/启用捏合手势来完全控制是否可以缩放
    self.scrollView.pinchGestureRecognizer.enabled = zoomEnabled;
    
    // 开启缩放时，禁用绘图；关闭缩放时，开启绘图
    self.drawingView.userInteractionEnabled = !zoomEnabled;
}

#pragma mark - Public Methods

- (void)undo {
    [self.drawingView undo];
}

- (void)redo {
    [self.drawingView redo];
}

- (void)clearDrawing {
    [self.drawingView clearDrawing];
}

- (void)restoreAllDrawing {
    [self.drawingView restoreAllDrawing];
}

- (UIImage *)captureVisibleAreaAsImage {
    // 确保使用正确的比例进行截图，以保证清晰度
    UIGraphicsBeginImageContextWithOptions(self.contentContainerView.bounds.size, NO, 0.0);
    
    CGContextRef context = UIGraphicsGetCurrentContext();
    
    // 先绘制背景图片
    [self.imageView.layer renderInContext:context];
    
    // 再绘制上层的画板
    [self.drawingView.layer renderInContext:context];
    
    UIImage *capturedImage = UIGraphicsGetImageFromCurrentImageContext();
    UIGraphicsEndImageContext();
    
    return capturedImage;
}

- (UIImage *)captureDrawingWithOriginalSize {
    // 获取背景图片，如果没有背景图片则返回nil
    UIImage *backgroundImage = self.imageView.image;
    if (!backgroundImage || !backgroundImage.CGImage) {
        NSLog(@"[DrawingBoardView] Capture failed: Background image is nil or has no CGImage.");
        return nil;
    }
    
    // 使用CGImage获取真实的像素尺寸
    CGImageRef bgCGImage = backgroundImage.CGImage;
    size_t width = CGImageGetWidth(bgCGImage);
    size_t height = CGImageGetHeight(bgCGImage);
    
    // 创建位图上下文，使用现代的CGBitmapContextCreate方法
    size_t bitsPerComponent = 8;
    size_t bytesPerRow = width * 4; // RGBA
    
    CGColorSpaceRef colorSpace = CGColorSpaceCreateDeviceRGB();
    CGContextRef context = CGBitmapContextCreate(NULL, width, height, bitsPerComponent, bytesPerRow, colorSpace, kCGImageAlphaPremultipliedLast);
    CGColorSpaceRelease(colorSpace);
    
    if (!context) {
        NSLog(@"[DrawingBoardView] Capture failed: CGBitmapContextCreate returned NULL.");
        return nil;
    }
    
    // 先绘制背景图片（不翻转坐标系）
    CGRect imageRect = CGRectMake(0, 0, width, height);
    CGContextDrawImage(context, imageRect, bgCGImage);
    
    // 计算从视图坐标到图片坐标的映射比例
    CGFloat scaleX = (CGFloat)width / self.drawingView.bounds.size.width;
    CGFloat scaleY = (CGFloat)height / self.drawingView.bounds.size.height;
    
    // 为绘图内容翻转坐标系，因为绘图数据是基于UIKit坐标系的
    CGContextSaveGState(context);
    CGContextTranslateCTM(context, 0, height);
    CGContextScaleCTM(context, 1.0, -1.0);
    
    // 直接将绘图对象映射到目标尺寸进行绘制，避免二次缩放
    [self drawItemsDirectlyToContext:context targetWidth:width targetHeight:height scaleX:scaleX scaleY:scaleY];
    
    // 恢复坐标系
    CGContextRestoreGState(context);
    
    // 从位图上下文创建CGImage
    CGImageRef cgImage = CGBitmapContextCreateImage(context);
    CGContextRelease(context);
    
    if (!cgImage) {
        NSLog(@"[DrawingBoardView] Capture failed: CGBitmapContextCreateImage returned NULL.");
        return nil;
    }
    
    // 根据背景图片的scale来决定最终图片的scale
    CGFloat imageScale = backgroundImage.scale;
    UIImage *capturedImage = [UIImage imageWithCGImage:cgImage scale:imageScale orientation:UIImageOrientationUp];
    CGImageRelease(cgImage);
    
    return capturedImage;
}

#pragma mark - Direct Drawing Methods

- (void)drawItemsDirectlyToContext:(CGContextRef)context targetWidth:(size_t)targetWidth targetHeight:(size_t)targetHeight scaleX:(CGFloat)scaleX scaleY:(CGFloat)scaleY {
    // 获取DrawingView中的所有绘图对象
    NSArray *drawnItems = [self.drawingView getDrawnItems];
    
    for (id item in drawnItems) {
        if ([item isKindOfClass:[DrawingShape class]]) {
            [self drawShapeDirectly:(DrawingShape *)item toContext:context scaleX:scaleX scaleY:scaleY];
        } else if ([item isKindOfClass:[DrawingText class]]) {
            [self drawTextDirectly:(DrawingText *)item toContext:context scaleX:scaleX scaleY:scaleY];
        }
    }
}

- (void)drawShapeDirectly:(DrawingShape *)shape toContext:(CGContextRef)context scaleX:(CGFloat)scaleX scaleY:(CGFloat)scaleY {
    // 保存图形状态
    CGContextSaveGState(context);
    
    // 直接创建映射到目标尺寸的路径，避免二次缩放
    UIBezierPath *targetPath = [UIBezierPath bezierPath];
    
    // 获取原始路径的所有点，直接映射到目标坐标系
    CGPathRef originalPath = shape.path.CGPath;
    CGPathApplierInfo info = {targetPath, scaleX, scaleY};
    CGPathApply(originalPath, &info, pathApplierFunction);
    
    // 添加路径到上下文
    CGContextAddPath(context, targetPath.CGPath);
    
    // 设置线宽（直接映射到目标尺寸）
    CGContextSetLineWidth(context, shape.lineWidth * scaleX);
    
    // 设置虚线样式（直接映射到目标尺寸）
    if (shape.lineDashPattern && shape.lineDashPattern.count > 0) {
        size_t count = shape.lineDashPattern.count;
        // 动态分配内存以支持任意长度的虚线模式
        CGFloat *dashes = (CGFloat *)malloc(count * sizeof(CGFloat));
        if (dashes) {
            for (size_t i = 0; i < count; i++) {
                NSNumber *dashValue = shape.lineDashPattern[i];
                if (dashValue && [dashValue isKindOfClass:[NSNumber class]]) {
                    CGFloat dashLength = [dashValue floatValue];
                    // 确保虚线长度为正值
                    dashes[i] = MAX(1.0, dashLength) * scaleX;
                } else {
                    dashes[i] = 5.0 * scaleX; // 默认值
                }
            }
            CGContextSetLineDash(context, 0, dashes, count);
            free(dashes); // 释放内存
        }
    } else {
        CGContextSetLineDash(context, 0, NULL, 0);
    }
    
    // 绘制填充
    if (shape.fillColor) {
        CGContextSetFillColorWithColor(context, shape.fillColor.CGColor);
        CGContextFillPath(context);
        CGContextAddPath(context, targetPath.CGPath); // 重新添加路径用于描边
    }
    
    // 绘制描边
    CGContextSetStrokeColorWithColor(context, shape.strokeColor.CGColor);
    CGContextStrokePath(context);
    
    // 恢复图形状态
    CGContextRestoreGState(context);
}

- (void)drawTextDirectly:(DrawingText *)drawingText toContext:(CGContextRef)context scaleX:(CGFloat)scaleX scaleY:(CGFloat)scaleY {
    // 保存图形状态
    CGContextSaveGState(context);
    
    // 获取文本属性
    NSString *text = drawingText.text;
    NSDictionary *attributes = drawingText.attributes;
    CGPoint origin = drawingText.origin;
    
    // 直接创建目标尺寸的文本属性
    NSMutableDictionary *targetAttributes = [attributes mutableCopy];
    UIFont *originalFont = attributes[NSFontAttributeName];
    if (originalFont) {
        CGFloat targetFontSize = originalFont.pointSize * scaleX;
        UIFont *targetFont = [UIFont fontWithName:originalFont.fontName size:targetFontSize];
        if (!targetFont) {
            targetFont = [UIFont systemFontOfSize:targetFontSize];
        }
        targetAttributes[NSFontAttributeName] = targetFont;
    }
    
    // 直接映射到目标位置
    CGPoint targetOrigin = CGPointMake(origin.x * scaleX, origin.y * scaleY);
    
    // 计算目标尺寸下的文本大小
    CGSize textSize = [text sizeWithAttributes:targetAttributes];
    
    // 父图形上下文是翻转的（Y 轴朝上）。为了简化文本绘制，我们应用一个局部变换
    // 来为此操作临时“反翻转”坐标系。这使我们可以在熟悉的自顶向下的坐标空间中绘制文本，
    // 从而避免在翻转的上下文中进行复杂的基线计算。
    CGContextTranslateCTM(context, 0, targetOrigin.y + textSize.height);
    CGContextScaleCTM(context, 1.0, -1.0);
    
    // 在这个新的局部坐标系中，我们可以定义一个从 y=0 开始的简单绘图矩形。
    CGRect textRect = CGRectMake(targetOrigin.x, 0, textSize.width, textSize.height);
    
    // 使用Core Text进行更精确的文本绘制
    CTFontRef font = (__bridge CTFontRef)targetAttributes[NSFontAttributeName];
    CGColorRef color = ((UIColor *)targetAttributes[NSForegroundColorAttributeName]).CGColor;
    
    if (font && color) {
        // 设置文本颜色
        CGContextSetFillColorWithColor(context, color);
        
        // 创建属性字符串
        CFStringRef string = (__bridge CFStringRef)text;
        CFMutableDictionaryRef attrs = CFDictionaryCreateMutable(kCFAllocatorDefault, 0, &kCFTypeDictionaryKeyCallBacks, &kCFTypeDictionaryValueCallBacks);
        CFDictionarySetValue(attrs, kCTFontAttributeName, font);
        CFDictionarySetValue(attrs, kCTForegroundColorAttributeName, color);
        
        CFAttributedStringRef attrString = CFAttributedStringCreate(kCFAllocatorDefault, string, attrs);
        CTLineRef line = CTLineCreateWithAttributedString(attrString);
        
        // 设置文本位置并绘制
        CGContextSetTextPosition(context, textRect.origin.x, textRect.origin.y);
        CTLineDraw(line, context);
        
        // 释放Core Text对象
        CFRelease(line);
        CFRelease(attrString);
        CFRelease(attrs);
    } else {
        // 降级到NSString绘制方法
        [text drawInRect:textRect withAttributes:targetAttributes];
    }
    
    // 恢复图形状态
    CGContextRestoreGState(context);
}

// CGPath应用函数，用于直接映射路径点
typedef struct {
    UIBezierPath *targetPath; // 移除unsafe_unretained，在函数调用期间对象是安全的
    CGFloat scaleX;
    CGFloat scaleY;
} CGPathApplierInfo;

void pathApplierFunction(void *info, const CGPathElement *element) {
    CGPathApplierInfo *applierInfo = (CGPathApplierInfo *)info;
    UIBezierPath *targetPath = applierInfo->targetPath;
    CGFloat scaleX = applierInfo->scaleX;
    CGFloat scaleY = applierInfo->scaleY;
    
    switch (element->type) {
        case kCGPathElementMoveToPoint: {
            CGPoint point = element->points[0];
            CGPoint scaledPoint = CGPointMake(point.x * scaleX, point.y * scaleY);
            [targetPath moveToPoint:scaledPoint];
            break;
        }
        case kCGPathElementAddLineToPoint: {
            CGPoint point = element->points[0];
            CGPoint scaledPoint = CGPointMake(point.x * scaleX, point.y * scaleY);
            [targetPath addLineToPoint:scaledPoint];
            break;
        }
        case kCGPathElementAddQuadCurveToPoint: {
            CGPoint controlPoint = element->points[0];
            CGPoint endPoint = element->points[1];
            CGPoint scaledControlPoint = CGPointMake(controlPoint.x * scaleX, controlPoint.y * scaleY);
            CGPoint scaledEndPoint = CGPointMake(endPoint.x * scaleX, endPoint.y * scaleY);
            [targetPath addQuadCurveToPoint:scaledEndPoint controlPoint:scaledControlPoint];
            break;
        }
        case kCGPathElementAddCurveToPoint: {
            CGPoint controlPoint1 = element->points[0];
            CGPoint controlPoint2 = element->points[1];
            CGPoint endPoint = element->points[2];
            CGPoint scaledControlPoint1 = CGPointMake(controlPoint1.x * scaleX, controlPoint1.y * scaleY);
            CGPoint scaledControlPoint2 = CGPointMake(controlPoint2.x * scaleX, controlPoint2.y * scaleY);
            CGPoint scaledEndPoint = CGPointMake(endPoint.x * scaleX, endPoint.y * scaleY);
            [targetPath addCurveToPoint:scaledEndPoint controlPoint1:scaledControlPoint1 controlPoint2:scaledControlPoint2];
            break;
        }
        case kCGPathElementCloseSubpath:
            [targetPath closePath];
            break;
    }
}

@end
