#import "DrawingView.h"
#import "DrawingTypes.h"
#import "DrawingShape.h"
#import "DrawingText.h"

// Enum to identify control points for resizing
typedef NS_ENUM(NSInteger, ControlPointPosition) {
    ControlPointPositionNone,
    ControlPointPositionTopLeft,
    ControlPointPositionTopRight,
    ControlPointPositionBottomLeft,
    ControlPointPositionBottomRight
};

@interface DrawingView () <UITextViewDelegate>

// Drawing data
@property (nonatomic, strong, nullable) id originalItemForTransform; // Store the item's state at the beginning of a transform
@property (nonatomic, assign) CGPoint dragStartPoint; // The point where the drag began
@property (nonatomic, strong) NSMutableArray<id> *drawnItems;
@property (nonatomic, strong) NSMutableArray<NSDictionary *> *undoStack;
@property (nonatomic, strong) NSMutableArray<NSDictionary *> *redoStack;

// Current drawing state
@property (nonatomic, strong) UIBezierPath *currentPath;
@property (nonatomic, assign) CGPoint startPoint;

// Selection and editing state
@property (nonatomic, assign) CGPoint previousTouchPoint;
@property (nonatomic, assign) ControlPointPosition activeControlPoint;
@property (nonatomic, strong) NSArray<NSValue *> *controlPointRects;
@property (nonatomic, assign) BOOL undoActionRegisteredForCurrentDrag;

// Text input
@property (nonatomic, strong) UITextView *activeTextView;

@end

@implementation DrawingView

#pragma mark - Initialization

- (instancetype)initWithFrame:(CGRect)frame {
    self = [super initWithFrame:frame];
    if (self) {
        [self setup];
    }
    return self;
}

- (instancetype)initWithCoder:(NSCoder *)coder {
    self = [super initWithCoder:coder];
    if (self) {
        [self setup];
    }
    return self;
}

- (void)setup {
    self.backgroundColor = [UIColor clearColor];
    _drawnItems = [NSMutableArray array];
    _undoStack = [NSMutableArray array];
    _redoStack = [NSMutableArray array];
    
    // Default properties
    _currentTool = DrawingToolTypePen;
    _strokeColor = [UIColor blackColor];
    _fillColor = nil;
    _lineWidth = 2.0;
    _lineDashPattern = nil;
    _fontSize = 24.0;
    
    _activeControlPoint = ControlPointPositionNone;
}

#pragma mark - Touch Handling

- (void)touchesBegan:(NSSet<UITouch *> *)touches withEvent:(UIEvent *)event {
    if (self.activeTextView) {
        [self.activeTextView resignFirstResponder];
        return;
    }
    
    UITouch *touch = [touches anyObject];
    CGPoint touchPoint = [touch locationInView:self];
    
    self.undoActionRegisteredForCurrentDrag = NO;

    switch (self.currentTool) {
        case DrawingToolTypeSelector:
        {
            // 首先检查是否点击在控制角上（仅当有选中项时）
            if (self.selectedItem) {
                self.activeControlPoint = [self controlPointAtPoint:touchPoint];
                if (self.activeControlPoint != ControlPointPositionNone) {
                    // 开始缩放操作
                    self.dragStartPoint = touchPoint;
                    self.originalItemForTransform = [self.selectedItem copy];
                    return;
                }
                
                // 检查是否点击在选中项的蓝框内（用于移动）
                if ([self isPointInSelectedItemBounds:touchPoint]) {
                    // 开始移动操作
                    self.dragStartPoint = touchPoint;
                    self.originalItemForTransform = [self.selectedItem copy];
                    return;
                }
            }
            
            // 检查是否点击在其他图案的路径上
            id hitItem = [self findItemAtPoint:touchPoint];
            if (hitItem) {
                // 选中新图案
                self.selectedItem = hitItem;
                [self setNeedsDisplay];
                if ([self.delegate respondsToSelector:@selector(drawingView:didSelectItem:)]) {
                    [self.delegate drawingView:self didSelectItem:self.selectedItem];
                }
            } else {
                // 点击在空白区域，取消选中
                self.selectedItem = nil;
                self.controlPointRects = nil;
                [self setNeedsDisplay];
                if ([self.delegate respondsToSelector:@selector(drawingView:didSelectItem:)]) {
                    [self.delegate drawingView:self didSelectItem:nil];
                }
            }
            self.originalItemForTransform = nil;
            return;
        }
            
        case DrawingToolTypeEraser:
            if (self.selectedItem) {
                [self deleteSelectedItem];
            } else {
                [self eraseItemAtPoint:touchPoint];
            }
            return;
            
        case DrawingToolTypeTextBox:
            [self showTextInputViewAtPoint:touchPoint];
            return;
            
        default:
            self.selectedItem = nil;
            self.startPoint = touchPoint;
            self.currentPath = [UIBezierPath bezierPath];
            [self.currentPath moveToPoint:self.startPoint];
            break;
    }
}

- (void)touchesMoved:(NSSet<UITouch *> *)touches withEvent:(UIEvent *)event {
    UITouch *touch = [touches anyObject];
    CGPoint currentPoint = [touch locationInView:self];

    switch (self.currentTool) {
        case DrawingToolTypeSelector:
            if (self.activeControlPoint != ControlPointPositionNone) {
                [self registerUndoForCurrentEdit];
                [self resizeSelectedItemWithTouchPoint:currentPoint];
                [self setNeedsDisplay];
            } else if (self.selectedItem && self.originalItemForTransform) {
                [self registerUndoForCurrentEdit];
                [self moveSelectedItemToPoint:currentPoint];
                [self setNeedsDisplay];
            }
            break;
            
        case DrawingToolTypeEraser:
            [self eraseItemAtPoint:currentPoint];
            break;
            
        case DrawingToolTypeTextBox:
            // Text box position is set on touchesBegan, no action on move.
            break;

        case DrawingToolTypePen:
            [self.currentPath addLineToPoint:currentPoint];
            [self setNeedsDisplay];
            break;

        default: // Handles Line, Arrow, Rectangle, Oval, etc.
            [self.currentPath removeAllPoints];
            [self.currentPath moveToPoint:self.startPoint];
            [self drawShapeWithEndPoint:currentPoint];
            [self setNeedsDisplay];
            break;
    }
}

- (void)touchesEnded:(NSSet<UITouch *> *)touches withEvent:(UIEvent *)event {
    self.undoActionRegisteredForCurrentDrag = NO;
    
    // Finalize shape drawing for tools that use a temporary path
    switch (self.currentTool) {
        case DrawingToolTypePen:
        case DrawingToolTypeLine:
        case DrawingToolTypeArrow:
        case DrawingToolTypeRectangle:
        case DrawingToolTypeOval:
        case DrawingToolTypeTriangle:
        case DrawingToolTypeStar:
        case DrawingToolTypeCircle:
        case DrawingToolTypeSineWave:
        case DrawingToolTypeCosineWave:
        case DrawingToolTypePentagon:
        case DrawingToolTypeTrapezoid:
        case DrawingToolTypeDiamond:
        case DrawingToolTypeCoordinateSystem:
        case DrawingToolTypePyramid:
        case DrawingToolTypeCone:
        case DrawingToolTypeCylinder:
        case DrawingToolTypeCube:
        {
            if (self.currentPath && !self.currentPath.isEmpty) {
                UIColor *currentFillColor = nil;
                // Check if the tool should have a fill color
                if ((self.currentTool >= DrawingToolTypeRectangle && self.currentTool <= DrawingToolTypeStar) || 
                    self.currentTool == DrawingToolTypeCircle ||
                    self.currentTool == DrawingToolTypePentagon ||
                    self.currentTool == DrawingToolTypeTrapezoid ||
                    self.currentTool == DrawingToolTypeDiamond ||
                    self.currentTool == DrawingToolTypePyramid ||
                    self.currentTool == DrawingToolTypeCone ||
                    self.currentTool == DrawingToolTypeCylinder ||
                    self.currentTool == DrawingToolTypeCube) {
                    currentFillColor = self.fillColor;
                }
                
                DrawingShape *shape = [DrawingShape shapeWithPath:self.currentPath
                                                      strokeColor:self.strokeColor
                                                        fillColor:currentFillColor
                                                        lineWidth:self.lineWidth
                                                  lineDashPattern:self.lineDashPattern];
                [self.drawnItems addObject:shape];
                
                [self.undoStack addObject:@{@"type": @"add", @"item": shape}];
                [self.redoStack removeAllObjects];
            }
            self.currentPath = nil;
            [self setNeedsDisplay];
        }
            break;
            
        default:
            // For Selector, Eraser, TextBox, no shape is finalized here
            break;
    }
    
    // Reset the active control point after a resize/move operation is complete
    if (self.currentTool == DrawingToolTypeSelector) {
        self.activeControlPoint = ControlPointPositionNone;
        self.originalItemForTransform = nil; // Clear original state
    }
}

#pragma mark - Drawing

- (void)drawRect:(CGRect)rect {
    for (id item in self.drawnItems) {
        if ([item isKindOfClass:[DrawingShape class]]) {
            [self drawShape:(DrawingShape *)item];
        } else if ([item isKindOfClass:[DrawingText class]]) {
            [self drawText:(DrawingText *)item];
        }
    }
    
    if (self.currentPath) {
        [self drawPreviewShape];
    }
    
    if (self.selectedItem) {
        [self drawHighlightForSelectedItem];
    }
}

- (void)drawShape:(DrawingShape *)shape {
    if (shape.fillColor) {
        [shape.fillColor setFill];
        [shape.path fill];
    }
    [shape.strokeColor setStroke];
    shape.path.lineWidth = shape.lineWidth;
    [self applyLineDashPattern:shape.lineDashPattern toPath:shape.path];
    [shape.path stroke];
    [self applyLineDashPattern:nil toPath:shape.path];
}

- (void)drawText:(DrawingText *)drawingText {
    [drawingText.text drawInRect:[drawingText boundingRect] withAttributes:drawingText.attributes];
}

- (void)applyLineDashPattern:(nullable NSArray<NSNumber *> *)pattern toPath:(UIBezierPath *)path {
    if (pattern.count > 0) {
        NSInteger count = pattern.count;
        CGFloat dashes[count];
        for (int i = 0; i < count; i++) {
            dashes[i] = [pattern[i] floatValue];
        }
        [path setLineDash:dashes count:count phase:0];
    } else {
        [path setLineDash:NULL count:0 phase:0];
    }
}

- (void)drawPreviewShape {
    if (self.fillColor && ((self.currentTool >= DrawingToolTypeRectangle && self.currentTool <= DrawingToolTypeStar) || self.currentTool == DrawingToolTypeCircle)) {
        [self.fillColor setFill];
        [self.currentPath fill];
    }
    [self.strokeColor setStroke];
    self.currentPath.lineWidth = self.lineWidth;
    [self applyLineDashPattern:self.lineDashPattern toPath:self.currentPath];
    [self.currentPath stroke];
}

#pragma mark - Shape Drawing Helpers

- (void)drawShapeWithEndPoint:(CGPoint)endPoint {
    CGRect rect = CGRectMake(self.startPoint.x, self.startPoint.y, endPoint.x - self.startPoint.x, endPoint.y - self.startPoint.y);
    rect = CGRectStandardize(rect);

    switch (self.currentTool) {
        case DrawingToolTypeLine:
            [self.currentPath addLineToPoint:endPoint];
            break;
        case DrawingToolTypeArrow:
            [self drawArrowFrom:self.startPoint to:endPoint];
            break;
        case DrawingToolTypeRectangle:
            self.currentPath = [UIBezierPath bezierPathWithRect:rect];
            break;
        case DrawingToolTypeOval:
            self.currentPath = [UIBezierPath bezierPathWithOvalInRect:rect];
            break;
        case DrawingToolTypeTriangle:
            [self drawTriangleInRect:rect];
            break;
        case DrawingToolTypeStar:
            [self drawStarInRect:rect];
            break;
        case DrawingToolTypeCircle:
            [self drawCircleInRect:rect];
            break;
        // 新增图形类型
        case DrawingToolTypeSineWave:
            [self drawSineWaveInRect:rect];
            break;
        case DrawingToolTypeCosineWave:
            [self drawCosineWaveInRect:rect];
            break;
        case DrawingToolTypePentagon:
            [self drawPentagonInRect:rect];
            break;
        case DrawingToolTypeTrapezoid:
            [self drawTrapezoidInRect:rect];
            break;
        case DrawingToolTypeDiamond:
            [self drawDiamondInRect:rect];
            break;
        case DrawingToolTypeCoordinateSystem:
            [self drawCoordinateSystemInRect:rect];
            break;
        case DrawingToolTypePyramid:
            [self drawPyramidInRect:rect];
            break;
        case DrawingToolTypeCone:
            [self drawConeInRect:rect];
            break;
        case DrawingToolTypeCylinder:
            [self drawCylinderInRect:rect];
            break;
        case DrawingToolTypeCube:
            [self drawCubeInRect:rect];
            break;
        default:
            break;
    }
}

- (void)drawCircleInRect:(CGRect)rect {
    [self.currentPath removeAllPoints];
    if (CGRectIsEmpty(rect)) return;
    CGFloat sideLength = MIN(CGRectGetWidth(rect), CGRectGetHeight(rect));
    // Since the rect is standardized before this call, its width and height are non-negative.
    // We create a square with the smaller side length, anchored at the rect's origin.
    CGRect squareRect = CGRectMake(rect.origin.x, rect.origin.y, sideLength, sideLength);
    self.currentPath = [UIBezierPath bezierPathWithOvalInRect:squareRect];
}

- (void)drawArrowFrom:(CGPoint)start to:(CGPoint)end {
    [self.currentPath removeAllPoints];
    
    // 计算箭头参数，调整到最佳尺寸
    CGFloat angle = atan2(end.y - start.y, end.x - start.x);
    CGFloat arrowLength = MAX(8.0, self.lineWidth * 1.3); // 再次减小箭头长度
    CGFloat arrowWidth = MAX(4.0, self.lineWidth * 0.8);  // 再次减小箭头宽度
    CGFloat arrowAngle = atan2(arrowWidth, arrowLength);
    
    // 计算箭头的两个边点
    CGPoint arrowPoint1 = CGPointMake(end.x - arrowLength * cos(angle - arrowAngle), 
                                     end.y - arrowLength * sin(angle - arrowAngle));
    CGPoint arrowPoint2 = CGPointMake(end.x - arrowLength * cos(angle + arrowAngle), 
                                     end.y - arrowLength * sin(angle + arrowAngle));
    
    // 计算主线条应该结束的位置，让线条延伸到箭头底部
    CGFloat lineEndOffset = arrowLength * 0.8; // 主线条延伸到箭头底部附近
    CGPoint lineEnd = CGPointMake(end.x - lineEndOffset * cos(angle), 
                                 end.y - lineEndOffset * sin(angle));
    
    // 绘制主线条（从起点到箭头底部）
    [self.currentPath moveToPoint:start];
    [self.currentPath addLineToPoint:lineEnd];
    
    // 绘制箭头三角形，确保与主线条连接良好
    [self.currentPath moveToPoint:lineEnd];  // 从线条结束点开始
    [self.currentPath addLineToPoint:arrowPoint1];
    [self.currentPath addLineToPoint:end];
    [self.currentPath addLineToPoint:arrowPoint2];
    [self.currentPath addLineToPoint:lineEnd];  // 回到起始点形成封闭路径
}

- (void)drawTriangleInRect:(CGRect)rect {
    [self.currentPath removeAllPoints];
    if (CGRectIsEmpty(rect)) return;
    CGPoint topPoint = CGPointMake(CGRectGetMidX(rect), CGRectGetMinY(rect));
    CGPoint bottomLeftPoint = CGPointMake(CGRectGetMinX(rect), CGRectGetMaxY(rect));
    CGPoint bottomRightPoint = CGPointMake(CGRectGetMaxX(rect), CGRectGetMaxY(rect));
    [self.currentPath moveToPoint:topPoint];
    [self.currentPath addLineToPoint:bottomLeftPoint];
    [self.currentPath addLineToPoint:bottomRightPoint];
    [self.currentPath closePath];
}

- (void)drawStarInRect:(CGRect)rect {
    [self.currentPath removeAllPoints];
    if (CGRectIsEmpty(rect)) return;
    CGFloat centerX = CGRectGetMidX(rect);
    CGFloat centerY = CGRectGetMidY(rect);
    CGFloat radius = MIN(CGRectGetWidth(rect), CGRectGetHeight(rect)) / 2.0;
    CGFloat angleIncrement = M_PI * 4.0 / 5.0;
    CGFloat angle = -M_PI_2;
    [self.currentPath moveToPoint:CGPointMake(centerX + radius * cos(angle), centerY + radius * sin(angle))];
    for (int i = 1; i < 5; i++) {
        angle += angleIncrement;
        [self.currentPath addLineToPoint:CGPointMake(centerX + radius * cos(angle), centerY + radius * sin(angle))];
    }
    [self.currentPath closePath];
}

#pragma mark - Selection & Transformation

// 私有方法：检查点是否在图形项内
- (BOOL)isPoint:(CGPoint)point inItem:(id)item {
    BOOL containsPoint = NO;
    
    if ([item isKindOfClass:[DrawingShape class]]) {
        DrawingShape *shape = (DrawingShape *)item;
        // 先检查填充区域（更快）
        if (shape.fillColor && [shape.path containsPoint:point]) {
            containsPoint = YES;
        } else {
            // 检查路径上的点击（包括描边区域）
            CGPathRef strokedPath = CGPathCreateCopyByStrokingPath(shape.path.CGPath, NULL, MAX(shape.lineWidth, 15.0), kCGLineCapRound, kCGLineJoinRound, 0);
            if (strokedPath) {
                containsPoint = CGPathContainsPoint(strokedPath, NULL, point, NO);
                CGPathRelease(strokedPath);
            }
        }
    } else if ([item isKindOfClass:[DrawingText class]]) {
        containsPoint = CGRectContainsPoint([(DrawingText *)item boundingRect], point);
    }
    
    return containsPoint;
}

// 查找指定点击位置的图案（按照路径精确检测）
- (nullable id)findItemAtPoint:(CGPoint)point {
    for (NSInteger i = self.drawnItems.count - 1; i >= 0; i--) {
        id item = self.drawnItems[i];
        if ([self isPoint:point inItem:item]) {
            return item;
        }
    }
    return nil;
}

// 检查点击位置是否在选中项的蓝框内（用于移动操作）
- (BOOL)isPointInSelectedItemBounds:(CGPoint)point {
    if (!self.selectedItem) return NO;
    
    CGRect boundingBox;
    if ([self.selectedItem isKindOfClass:[DrawingShape class]]) {
        boundingBox = CGRectInset(((DrawingShape *)self.selectedItem).frame, -5, -5);
    } else if ([self.selectedItem isKindOfClass:[DrawingText class]]) {
        boundingBox = CGRectInset([((DrawingText *)self.selectedItem) boundingRect], -5, -5);
    } else {
        return NO;
    }
    
    return CGRectContainsPoint(boundingBox, point);
}

// 保留原有的选择方法（用于兼容性，但现在主要使用findItemAtPoint）
- (void)selectItemAtPoint:(CGPoint)point {
    id foundItem = [self findItemAtPoint:point];
    self.selectedItem = foundItem;
    if (!foundItem) {
        self.controlPointRects = nil;
    }
    [self setNeedsDisplay];
    
    if ([self.delegate respondsToSelector:@selector(drawingView:didSelectItem:)]) {
        [self.delegate drawingView:self didSelectItem:self.selectedItem];
    }
}

- (void)moveSelectedItemToPoint:(CGPoint)currentPoint {
    if (!self.selectedItem || !self.originalItemForTransform) return;

    // 计算从开始拖拽点到当前点的偏移量
    CGFloat dx = currentPoint.x - self.dragStartPoint.x;
    CGFloat dy = currentPoint.y - self.dragStartPoint.y;

    if ([self.selectedItem isKindOfClass:[DrawingShape class]] && [self.originalItemForTransform isKindOfClass:[DrawingShape class]]) {
        DrawingShape *currentShape = (DrawingShape *)self.selectedItem;
        DrawingShape *originalShape = (DrawingShape *)self.originalItemForTransform;
        
        // 安全检查：确保原始路径存在
        if (!originalShape.path) return;
        
        // 从原始状态开始应用平移变换，确保移动跟手
        UIBezierPath *newPath = [originalShape.path copy];
        if (newPath) {
            CGAffineTransform translation = CGAffineTransformMakeTranslation(dx, dy);
            [newPath applyTransform:translation];
            currentShape.path = newPath;
        }
        
    } else if ([self.selectedItem isKindOfClass:[DrawingText class]] && [self.originalItemForTransform isKindOfClass:[DrawingText class]]) {
        DrawingText *currentText = (DrawingText *)self.selectedItem;
        DrawingText *originalText = (DrawingText *)self.originalItemForTransform;

        // 从原始位置开始计算新位置，确保移动跟手
        CGPoint newOrigin = CGPointMake(originalText.origin.x + dx, originalText.origin.y + dy);
        currentText.origin = newOrigin;
    }
}

- (void)resizeSelectedItemWithTouchPoint:(CGPoint)touchPoint {
    if (!self.selectedItem || !self.originalItemForTransform || self.activeControlPoint == ControlPointPositionNone) return;

    CGRect originalBounds;
    if ([self.originalItemForTransform isKindOfClass:[DrawingShape class]]) {
        originalBounds = ((DrawingShape *)self.originalItemForTransform).frame;
    } else if ([self.originalItemForTransform isKindOfClass:[DrawingText class]]) {
        originalBounds = [((DrawingText *)self.originalItemForTransform) boundingRect];
    } else {
        return;
    }

    // 1. 确定固定的锚点（对角点）
    CGPoint fixedAnchorPoint;
    switch (self.activeControlPoint) {
        case ControlPointPositionTopLeft:
            fixedAnchorPoint = CGPointMake(CGRectGetMaxX(originalBounds), CGRectGetMaxY(originalBounds));
            break;
        case ControlPointPositionTopRight:
            fixedAnchorPoint = CGPointMake(CGRectGetMinX(originalBounds), CGRectGetMaxY(originalBounds));
            break;
        case ControlPointPositionBottomLeft:
            fixedAnchorPoint = CGPointMake(CGRectGetMaxX(originalBounds), CGRectGetMinY(originalBounds));
            break;
        case ControlPointPositionBottomRight:
            fixedAnchorPoint = CGPointMake(CGRectGetMinX(originalBounds), CGRectGetMinY(originalBounds));
            break;
        default: return;
    }

    // 2. 计算拖拽偏移量（相对于开始拖拽的位置）
    CGFloat dx = touchPoint.x - self.dragStartPoint.x;
    CGFloat dy = touchPoint.y - self.dragStartPoint.y;
    
    // 3. 计算原始控制点位置
    CGPoint originalControlPoint;
    switch (self.activeControlPoint) {
        case ControlPointPositionTopLeft:
            originalControlPoint = CGPointMake(CGRectGetMinX(originalBounds), CGRectGetMinY(originalBounds));
            break;
        case ControlPointPositionTopRight:
            originalControlPoint = CGPointMake(CGRectGetMaxX(originalBounds), CGRectGetMinY(originalBounds));
            break;
        case ControlPointPositionBottomLeft:
            originalControlPoint = CGPointMake(CGRectGetMinX(originalBounds), CGRectGetMaxY(originalBounds));
            break;
        case ControlPointPositionBottomRight:
            originalControlPoint = CGPointMake(CGRectGetMaxX(originalBounds), CGRectGetMaxY(originalBounds));
            break;
        default: return;
    }
    
    // 4. 计算新的控制点位置
    CGPoint newControlPoint = CGPointMake(originalControlPoint.x + dx, originalControlPoint.y + dy);
    
    // 5. 计算新的尺寸
    CGFloat newWidth = fabs(newControlPoint.x - fixedAnchorPoint.x);
    CGFloat newHeight = fabs(newControlPoint.y - fixedAnchorPoint.y);
    
    // 防止尺寸过小
    if (newWidth < 10 || newHeight < 10) return;
    
    // 6. 等比缩放：使用较大的缩放比例
    CGFloat originalWidth = originalBounds.size.width;
    CGFloat originalHeight = originalBounds.size.height;
    
    if (originalWidth <= 0 || originalHeight <= 0) return;
    
    CGFloat scaleX = newWidth / originalWidth;
    CGFloat scaleY = newHeight / originalHeight;
    CGFloat uniformScale = MAX(scaleX, scaleY); // 使用较大的缩放比例保持等比
    
    // 7. 应用等比缩放变换
    if ([self.selectedItem isKindOfClass:[DrawingShape class]] && [self.originalItemForTransform isKindOfClass:[DrawingShape class]]) {
        DrawingShape *currentShape = (DrawingShape *)self.selectedItem;
        DrawingShape *originalShape = (DrawingShape *)self.originalItemForTransform;
        
        // 采用与文本缩放相同的简单直接方法
        
        // 1. 计算缩放后的新尺寸
        CGFloat newWidth = originalBounds.size.width * uniformScale;
        CGFloat newHeight = originalBounds.size.height * uniformScale;
        
        // 2. 根据固定锚点和新尺寸，直接计算新的边界框位置
        CGRect newBounds;
        switch (self.activeControlPoint) {
            case ControlPointPositionTopLeft:
                // 右下角固定，新的左上角 = 固定点 - 新尺寸
                newBounds = CGRectMake(fixedAnchorPoint.x - newWidth, 
                                     fixedAnchorPoint.y - newHeight,
                                     newWidth, newHeight);
                break;
            case ControlPointPositionTopRight:
                // 左下角固定，新的右上角 = 固定点 + (新宽度, -新高度)
                newBounds = CGRectMake(fixedAnchorPoint.x, 
                                     fixedAnchorPoint.y - newHeight,
                                     newWidth, newHeight);
                break;
            case ControlPointPositionBottomLeft:
                // 右上角固定，新的左下角 = 固定点 + (-新宽度, 新高度)
                newBounds = CGRectMake(fixedAnchorPoint.x - newWidth, 
                                     fixedAnchorPoint.y,
                                     newWidth, newHeight);
                break;
            case ControlPointPositionBottomRight:
                // 左上角固定，新的右下角 = 固定点 + 新尺寸
                newBounds = CGRectMake(fixedAnchorPoint.x, 
                                     fixedAnchorPoint.y,
                                     newWidth, newHeight);
                break;
            default:
                return;
        }
        
        // 3. 计算原始中心点和新中心点
        CGPoint originalCenter = CGPointMake(CGRectGetMidX(originalBounds), CGRectGetMidY(originalBounds));
        CGPoint newCenter = CGPointMake(CGRectGetMidX(newBounds), CGRectGetMidY(newBounds));
        
        // 4. 应用简单的变换：先缩放，再平移到正确位置
        UIBezierPath *newPath = [originalShape.path copy];
        
        // 以原始中心为基准进行缩放
        CGAffineTransform scaleTransform = CGAffineTransformMakeScale(uniformScale, uniformScale);
        CGAffineTransform translateToOrigin = CGAffineTransformMakeTranslation(-originalCenter.x, -originalCenter.y);
        CGAffineTransform translateToNewCenter = CGAffineTransformMakeTranslation(newCenter.x, newCenter.y);
        
        // 组合变换：移到原点 -> 缩放 -> 移到新中心
        CGAffineTransform finalTransform = CGAffineTransformConcat(translateToOrigin, scaleTransform);
        finalTransform = CGAffineTransformConcat(finalTransform, translateToNewCenter);
        
        [newPath applyTransform:finalTransform];
        currentShape.path = newPath;

    } else if ([self.selectedItem isKindOfClass:[DrawingText class]] && [self.originalItemForTransform isKindOfClass:[DrawingText class]]) {
        DrawingText *currentText = (DrawingText *)self.selectedItem;
        DrawingText *originalText = (DrawingText *)self.originalItemForTransform;
        
        // 对于文本，使用等比缩放
        CGFloat originalFontSize = [originalText.attributes[NSFontAttributeName] pointSize];
        CGFloat newFontSize = MAX(8.0, originalFontSize * uniformScale);
        UIFont *newFont = [UIFont systemFontOfSize:newFontSize];
        
        NSMutableDictionary *newAttributes = [currentText.attributes mutableCopy];
        newAttributes[NSFontAttributeName] = newFont;
        currentText.attributes = [newAttributes copy];
        
        // 计算文本的新位置，确保锚点固定
        CGSize textSize = [currentText.text sizeWithAttributes:newAttributes];
        CGPoint newOrigin;
        
        switch (self.activeControlPoint) {
            case ControlPointPositionTopLeft:
                newOrigin = CGPointMake(fixedAnchorPoint.x - textSize.width, fixedAnchorPoint.y - textSize.height);
                break;
            case ControlPointPositionTopRight:
                newOrigin = CGPointMake(fixedAnchorPoint.x, fixedAnchorPoint.y - textSize.height);
                break;
            case ControlPointPositionBottomLeft:
                newOrigin = CGPointMake(fixedAnchorPoint.x - textSize.width, fixedAnchorPoint.y);
                break;
            case ControlPointPositionBottomRight:
                newOrigin = fixedAnchorPoint;
                break;
            default:
                newOrigin = originalText.origin;
                break;
        }
        currentText.origin = newOrigin;
    }
}

#pragma mark - Selection Highlighting

- (void)drawHighlightForSelectedItem {
    if (!self.selectedItem) return;
    
    CGRect boundingBox;
    if ([self.selectedItem isKindOfClass:[DrawingShape class]]) {
        boundingBox = CGRectInset(((DrawingShape *)self.selectedItem).frame, -5, -5);
    } else if ([self.selectedItem isKindOfClass:[DrawingText class]]) {
        boundingBox = CGRectInset([((DrawingText *)self.selectedItem) boundingRect], -5, -5);
    } else {
        return;
    }
    
    UIBezierPath *highlightPath = [UIBezierPath bezierPathWithRect:boundingBox];
    [[UIColor systemBlueColor] setStroke];
    highlightPath.lineWidth = 1.5;
    CGFloat dashes[] = {6, 3};
    [highlightPath setLineDash:dashes count:2 phase:0];
    [highlightPath stroke];
    
    [self drawControlPointsForRect:boundingBox];
}

- (void)drawControlPointsForRect:(CGRect)rect {
    CGFloat handleSize = 32.0; // 增大控制角，提高可操作性
    CGRect topLeft = CGRectMake(CGRectGetMinX(rect) - handleSize / 2, CGRectGetMinY(rect) - handleSize / 2, handleSize, handleSize);
    CGRect topRight = CGRectMake(CGRectGetMaxX(rect) - handleSize / 2, CGRectGetMinY(rect) - handleSize / 2, handleSize, handleSize);
    CGRect bottomLeft = CGRectMake(CGRectGetMinX(rect) - handleSize / 2, CGRectGetMaxY(rect) - handleSize / 2, handleSize, handleSize);
    CGRect bottomRight = CGRectMake(CGRectGetMaxX(rect) - handleSize / 2, CGRectGetMaxY(rect) - handleSize / 2, handleSize, handleSize);
    
    self.controlPointRects = @[[NSValue valueWithCGRect:topLeft], [NSValue valueWithCGRect:topRight], [NSValue valueWithCGRect:bottomLeft], [NSValue valueWithCGRect:bottomRight]];
    
    // 绘制控制角（白色填充，蓝色边框）
    [[UIColor whiteColor] setFill];
    [[UIColor systemBlueColor] setStroke];
    for (NSValue *rectValue in self.controlPointRects) {
        CGRect controlRect = [rectValue CGRectValue];
        UIRectFill(controlRect);
        UIBezierPath *borderPath = [UIBezierPath bezierPathWithRect:controlRect];
        borderPath.lineWidth = 2.0;
        [borderPath stroke];
    }
}

- (ControlPointPosition)controlPointAtPoint:(CGPoint)point {
    if (!self.selectedItem) return ControlPointPositionNone;
    
    // 实时计算当前选中项的边界框和控制角位置
    CGRect boundingBox;
    if ([self.selectedItem isKindOfClass:[DrawingShape class]]) {
        boundingBox = CGRectInset(((DrawingShape *)self.selectedItem).frame, -5, -5);
    } else if ([self.selectedItem isKindOfClass:[DrawingText class]]) {
        boundingBox = CGRectInset([((DrawingText *)self.selectedItem) boundingRect], -5, -5);
    } else {
        return ControlPointPositionNone;
    }
    
    // 实时计算控制角位置
    CGFloat handleSize = 32.0;
    CGRect topLeft = CGRectMake(CGRectGetMinX(boundingBox) - handleSize / 2, CGRectGetMinY(boundingBox) - handleSize / 2, handleSize, handleSize);
    CGRect topRight = CGRectMake(CGRectGetMaxX(boundingBox) - handleSize / 2, CGRectGetMinY(boundingBox) - handleSize / 2, handleSize, handleSize);
    CGRect bottomLeft = CGRectMake(CGRectGetMinX(boundingBox) - handleSize / 2, CGRectGetMaxY(boundingBox) - handleSize / 2, handleSize, handleSize);
    CGRect bottomRight = CGRectMake(CGRectGetMaxX(boundingBox) - handleSize / 2, CGRectGetMaxY(boundingBox) - handleSize / 2, handleSize, handleSize);
    
    // 检测点击位置
    if (CGRectContainsPoint(topLeft, point)) return ControlPointPositionTopLeft;
    if (CGRectContainsPoint(topRight, point)) return ControlPointPositionTopRight;
    if (CGRectContainsPoint(bottomLeft, point)) return ControlPointPositionBottomLeft;
    if (CGRectContainsPoint(bottomRight, point)) return ControlPointPositionBottomRight;
    
    return ControlPointPositionNone;
}

#pragma mark - Text Input

- (void)showTextInputViewAtPoint:(CGPoint)point {
    self.activeTextView = [[UITextView alloc] initWithFrame:CGRectMake(point.x, point.y, 150, 40)];
    self.activeTextView.delegate = self;
    self.activeTextView.font = [UIFont systemFontOfSize:self.fontSize];
    self.activeTextView.textColor = self.strokeColor;
    self.activeTextView.backgroundColor = [UIColor colorWithWhite:0.95 alpha:0.7];
    self.activeTextView.layer.borderColor = [UIColor systemBlueColor].CGColor;
    self.activeTextView.layer.borderWidth = 1.0;
    self.activeTextView.returnKeyType = UIReturnKeyDone;
    [self addSubview:self.activeTextView];
    [self.activeTextView becomeFirstResponder];
}

- (void)textViewDidEndEditing:(UITextView *)textView {
    if (textView.text.length > 0) {
        UIFont *font = [UIFont systemFontOfSize:self.fontSize];
        NSDictionary *attributes = @{NSFontAttributeName: font, NSForegroundColorAttributeName: self.strokeColor};
        DrawingText *drawingText = [DrawingText text:textView.text atOrigin:textView.frame.origin withAttributes:attributes];
        [self.drawnItems addObject:drawingText];
        
        [self.undoStack addObject:@{@"type": @"add", @"item": drawingText}];
        [self.redoStack removeAllObjects];
    }
    [textView removeFromSuperview];
    self.activeTextView = nil;
    [self setNeedsDisplay];
}

- (BOOL)textView:(UITextView *)textView shouldChangeTextInRange:(NSRange)range replacementText:(NSString *)text {
    if ([text isEqualToString:@"\n"]) {
        [textView resignFirstResponder];
        return NO;
    }
    return YES;
}

#pragma mark - Property Editing

- (void)updateSelectedStrokeColor:(UIColor *)color {
    if (!self.selectedItem) return;
    [self registerUndoForEdit];
    if ([self.selectedItem isKindOfClass:[DrawingShape class]]) {
        ((DrawingShape *)self.selectedItem).strokeColor = color;
    } else if ([self.selectedItem isKindOfClass:[DrawingText class]]) {
        DrawingText *text = (DrawingText *)self.selectedItem;
        NSMutableDictionary *newAttributes = [text.attributes mutableCopy];
        newAttributes[NSForegroundColorAttributeName] = color;
        text.attributes = [newAttributes copy];
    }
    [self setNeedsDisplay];
}

- (void)updateSelectedFillColor:(nullable UIColor *)color {
    if ([self.selectedItem isKindOfClass:[DrawingShape class]]) {
        [self registerUndoForEdit];
        ((DrawingShape *)self.selectedItem).fillColor = color;
        [self setNeedsDisplay];
    }
}

- (void)updateSelectedLineWidth:(CGFloat)lineWidth {
    if ([self.selectedItem isKindOfClass:[DrawingShape class]]) {
        [self registerUndoForEdit];
        ((DrawingShape *)self.selectedItem).lineWidth = lineWidth;
        [self setNeedsDisplay];
    }
}

- (void)updateSelectedLineDashPattern:(nullable NSArray<NSNumber *> *)pattern {
    if ([self.selectedItem isKindOfClass:[DrawingShape class]]) {
        [self registerUndoForEdit];
        ((DrawingShape *)self.selectedItem).lineDashPattern = pattern;
        [self setNeedsDisplay];
    }
}

#pragma mark - Eraser Logic

- (void)deleteSelectedItem {
    if (!self.selectedItem) return;
    NSUInteger index = [self.drawnItems indexOfObject:self.selectedItem];
    if (index != NSNotFound) {
        [self.undoStack addObject:@{@"type": @"remove", @"item": self.selectedItem, @"index": @(index)}];
        [self.redoStack removeAllObjects];
        [self.drawnItems removeObjectAtIndex:index];
        self.selectedItem = nil;
        [self setNeedsDisplay];
    }
}

- (void)eraseItemAtPoint:(CGPoint)point {
    for (NSInteger i = self.drawnItems.count - 1; i >= 0; i--) {
        id item = self.drawnItems[i];
        if ([self isPoint:point inItem:item]) {
            [self.undoStack addObject:@{@"type": @"remove", @"item": item, @"index": @(i)}];
            [self.redoStack removeAllObjects];
            [self.drawnItems removeObjectAtIndex:i];
            [self setNeedsDisplay];
            break;
        }
    }
}

#pragma mark - Undo/Redo

- (void)registerUndoForCurrentEdit {
    if (self.undoActionRegisteredForCurrentDrag || !self.selectedItem) return;
    [self registerUndoForEdit];
    self.undoActionRegisteredForCurrentDrag = YES;
}

- (void)registerUndoForEdit {
    NSUInteger index = [self.drawnItems indexOfObject:self.selectedItem];
    if (index != NSNotFound) {
        [self.undoStack addObject:@{@"type": @"edit", @"item": [self.selectedItem copy], @"index": @(index)}];
        [self.redoStack removeAllObjects];
    }
}

- (void)undo {
    if (self.undoStack.count == 0) return;

    NSDictionary *lastAction = [self.undoStack lastObject];
    [self.undoStack removeLastObject];

    NSString *type = lastAction[@"type"];
    
    if ([type isEqualToString:@"restore"]) {
        // 处理还原操作的撤销
        NSArray *previousItems = lastAction[@"items"];
        [self.redoStack addObject:@{@"type": @"restore", @"items": [self.drawnItems copy]}];
        [self.drawnItems removeAllObjects];
        [self.drawnItems addObjectsFromArray:previousItems];
        self.selectedItem = nil;
    } else {
        // 处理其他操作
        id item = lastAction[@"item"];
        NSUInteger index = [lastAction[@"index"] unsignedIntegerValue];

        if ([type isEqualToString:@"add"]) {
            [self.drawnItems removeObject:item];
            if (self.selectedItem == item) self.selectedItem = nil;
            [self.redoStack addObject:lastAction];
        } else if ([type isEqualToString:@"remove"]) {
            // 安全检查：确保索引有效
            if (index <= self.drawnItems.count) {
                [self.drawnItems insertObject:item atIndex:index];
                self.selectedItem = item; // 修复：恢复选中状态
                [self.redoStack addObject:lastAction];
            }
        } else if ([type isEqualToString:@"edit"]) {
            // 安全检查：确保索引有效
            if (index < self.drawnItems.count) {
                id currentItem = self.drawnItems[index];
                [self.redoStack addObject:@{@"type": @"edit", @"item": [currentItem copy], @"index": @(index)}];
                [self.drawnItems replaceObjectAtIndex:index withObject:item];
                self.selectedItem = item;
            }
        }
    }
    [self setNeedsDisplay];
}

- (void)redo {
    if (self.redoStack.count == 0) return;

    NSDictionary *lastAction = [self.redoStack lastObject];
    [self.redoStack removeLastObject];

    NSString *type = lastAction[@"type"];
    
    if ([type isEqualToString:@"restore"]) {
        // 处理还原操作的重做
        NSArray *restoreItems = lastAction[@"items"];
        [self.undoStack addObject:@{@"type": @"restore", @"items": [self.drawnItems copy]}];
        [self.drawnItems removeAllObjects];
        [self.drawnItems addObjectsFromArray:restoreItems];
        self.selectedItem = nil;
    } else {
        // 处理其他操作
        id item = lastAction[@"item"];
        NSUInteger index = [lastAction[@"index"] unsignedIntegerValue];

        if ([type isEqualToString:@"add"]) {
            [self.drawnItems addObject:item];
            [self.undoStack addObject:lastAction];
        } else if ([type isEqualToString:@"remove"]) {
            // 安全检查：确保索引有效
            if (index < self.drawnItems.count) {
                [self.drawnItems removeObjectAtIndex:index];
                if (self.selectedItem == item) self.selectedItem = nil;
                [self.undoStack addObject:lastAction];
            }
        } else if ([type isEqualToString:@"edit"]) {
            // 安全检查：确保索引有效
            if (index < self.drawnItems.count) {
                id currentItem = self.drawnItems[index];
                [self.undoStack addObject:@{@"type": @"edit", @"item": [currentItem copy], @"index": @(index)}];
                [self.drawnItems replaceObjectAtIndex:index withObject:item];
                self.selectedItem = item;
            }
        }
    }
    [self setNeedsDisplay];
}

- (void)clearDrawing {
    // 在清空前，将当前状态保存到一个特殊的备份中
    if (self.drawnItems.count > 0) {
        NSArray *backupItems = [self.drawnItems copy];
        NSError *error;
        NSData *backupData = [NSKeyedArchiver archivedDataWithRootObject:backupItems requiringSecureCoding:YES error:&error];
        
        if (backupData && !error) {
            [[NSUserDefaults standardUserDefaults] setObject:backupData forKey:@"DrawingBackup"];
            [[NSUserDefaults standardUserDefaults] synchronize];
        } else {
            NSLog(@"Failed to backup drawing data: %@", error.localizedDescription);
        }
    }
    
    [self.drawnItems removeAllObjects];
    [self.undoStack removeAllObjects];
    [self.redoStack removeAllObjects];
    self.selectedItem = nil;
    [self setNeedsDisplay];
}

- (void)restoreAllDrawing {
    // 从备份中恢复所有绘图
    NSData *backupData = [[NSUserDefaults standardUserDefaults] objectForKey:@"DrawingBackup"];
    if (backupData) {
        NSError *error;
        // 扩展允许的类集合，包含所有可能的属性类
        NSSet *allowedClasses = [NSSet setWithObjects:
            [NSArray class], [NSMutableArray class],
            [DrawingShape class], [DrawingText class],
            [UIBezierPath class], [UIColor class], 
            [NSString class], [NSDictionary class], [NSMutableDictionary class],
            [NSNumber class], [UIFont class],
            nil];
        
        NSArray *backupItems = [NSKeyedUnarchiver unarchivedObjectOfClasses:allowedClasses fromData:backupData error:&error];
        
        if (backupItems && !error && [backupItems isKindOfClass:[NSArray class]]) {
            // 将当前状态保存到撤销栈（只有当前有内容时）
            if (self.drawnItems.count > 0) {
                NSMutableArray *currentItems = [self.drawnItems mutableCopy];
                [self.undoStack addObject:@{@"type": @"restore", @"items": currentItems}];
            }
            
            // 恢复备份的绘图
            [self.drawnItems removeAllObjects];
            [self.drawnItems addObjectsFromArray:backupItems];
            [self.redoStack removeAllObjects];
            self.selectedItem = nil;
            [self setNeedsDisplay];
            
            // 清除备份，避免重复恢复
            [[NSUserDefaults standardUserDefaults] removeObjectForKey:@"DrawingBackup"];
            [[NSUserDefaults standardUserDefaults] synchronize];
        } else {
            // 如果反序列化失败，清除损坏的备份数据
            [[NSUserDefaults standardUserDefaults] removeObjectForKey:@"DrawingBackup"];
            [[NSUserDefaults standardUserDefaults] synchronize];
            NSLog(@"Failed to restore drawing backup: %@", error.localizedDescription);
        }
    }
}

- (UIImage *)captureImage {
    UIGraphicsBeginImageContextWithOptions(self.bounds.size, NO, self.window.screen.scale);
    [self.layer renderInContext:UIGraphicsGetCurrentContext()];
    UIImage *image = UIGraphicsGetImageFromCurrentImageContext();
    UIGraphicsEndImageContext();
    return image;
}

#pragma mark - State Properties

- (BOOL)canUndo {
    return self.undoStack.count > 0;
}

- (BOOL)canRedo {
    return self.redoStack.count > 0;
}

- (NSArray *)getDrawnItems {
    return [self.drawnItems copy]; // 返回副本，防止外部修改
}

- (void)transformDrawnItemsFromSize:(CGSize)oldSize toSize:(CGSize)newSize {
    // 检查参数有效性
    if (oldSize.width <= 0 || oldSize.height <= 0 || newSize.width <= 0 || newSize.height <= 0) {
        return;
    }
    
    // 如果尺寸相同，无需变换
    if (CGSizeEqualToSize(oldSize, newSize)) {
        return;
    }
    
    // 计算等比缩放比例（使用较小的比例保持图案不变形）
    CGFloat scaleX = newSize.width / oldSize.width;
    CGFloat scaleY = newSize.height / oldSize.height;
    CGFloat uniformScale = MIN(scaleX, scaleY);
    
    // 计算居中偏移量
    CGFloat scaledOldWidth = oldSize.width * uniformScale;
    CGFloat scaledOldHeight = oldSize.height * uniformScale;
    CGFloat offsetX = (newSize.width - scaledOldWidth) / 2.0;
    CGFloat offsetY = (newSize.height - scaledOldHeight) / 2.0;
    
    // 遍历所有绘图项并应用等比变换
    for (id item in self.drawnItems) {
        if ([item isKindOfClass:[DrawingShape class]]) {
            DrawingShape *shape = (DrawingShape *)item;
            
            // 安全检查：确保路径存在
            if (!shape.path) continue;
            
            // 创建等比缩放变换矩阵
            CGAffineTransform transform = CGAffineTransformMakeScale(uniformScale, uniformScale);
            // 添加居中偏移
            transform = CGAffineTransformTranslate(transform, offsetX / uniformScale, offsetY / uniformScale);
            
            // 应用变换到路径
            [shape.path applyTransform:transform];
            
            // 调整线宽（使用等比缩放）
            shape.lineWidth = MAX(1.0, shape.lineWidth * uniformScale); // 确保线宽不小于1
            
        } else if ([item isKindOfClass:[DrawingText class]]) {
            DrawingText *text = (DrawingText *)item;
            
            // 安全检查：确保文本和属性存在
            if (!text.text || !text.attributes) continue;
            
            // 调整文本位置（等比缩放 + 居中偏移）
            CGFloat newX = text.origin.x * uniformScale + offsetX;
            CGFloat newY = text.origin.y * uniformScale + offsetY;
            text.origin = CGPointMake(newX, newY);
            
            // 调整字体大小（使用等比缩放）
            UIFont *currentFont = text.attributes[NSFontAttributeName];
            if (currentFont) {
                CGFloat newFontSize = MAX(8.0, currentFont.pointSize * uniformScale); // 确保字体不小于8
                UIFont *newFont = [UIFont fontWithName:currentFont.fontName size:newFontSize];
                if (!newFont) {
                    newFont = [UIFont systemFontOfSize:newFontSize];
                }
                
                NSMutableDictionary *newAttributes = [text.attributes mutableCopy];
                if (newAttributes) {
                    newAttributes[NSFontAttributeName] = newFont;
                    text.attributes = [newAttributes copy];
                }
            }
        }
    }
    
    // 重新绘制
    [self setNeedsDisplay];
}

#pragma mark - New Shape Drawing Methods

- (void)drawSineWaveInRect:(CGRect)rect {
    [self.currentPath removeAllPoints];
    if (CGRectIsEmpty(rect)) return;
    
    CGFloat width = CGRectGetWidth(rect);
    CGFloat height = CGRectGetHeight(rect);
    CGFloat centerY = CGRectGetMidY(rect);
    CGFloat amplitude = height / 2.0;
    CGFloat frequency = 2.0; // 2个周期
    
    BOOL firstPoint = YES;
    for (CGFloat x = 0; x <= width; x += 2.0) {
        CGFloat y = centerY + amplitude * sin((x / width) * frequency * 2 * M_PI);
        CGPoint point = CGPointMake(CGRectGetMinX(rect) + x, y);
        
        if (firstPoint) {
            [self.currentPath moveToPoint:point];
            firstPoint = NO;
        } else {
            [self.currentPath addLineToPoint:point];
        }
    }
}

- (void)drawCosineWaveInRect:(CGRect)rect {
    [self.currentPath removeAllPoints];
    if (CGRectIsEmpty(rect)) return;
    
    CGFloat width = CGRectGetWidth(rect);
    CGFloat height = CGRectGetHeight(rect);
    CGFloat centerY = CGRectGetMidY(rect);
    CGFloat amplitude = height / 2.0;
    CGFloat frequency = 2.0; // 2个周期
    
    BOOL firstPoint = YES;
    for (CGFloat x = 0; x <= width; x += 2.0) {
        CGFloat y = centerY + amplitude * cos((x / width) * frequency * 2 * M_PI);
        CGPoint point = CGPointMake(CGRectGetMinX(rect) + x, y);
        
        if (firstPoint) {
            [self.currentPath moveToPoint:point];
            firstPoint = NO;
        } else {
            [self.currentPath addLineToPoint:point];
        }
    }
}

- (void)drawPentagonInRect:(CGRect)rect {
    [self.currentPath removeAllPoints];
    if (CGRectIsEmpty(rect)) return;
    
    CGFloat centerX = CGRectGetMidX(rect);
    CGFloat centerY = CGRectGetMidY(rect);
    CGFloat radius = MIN(CGRectGetWidth(rect), CGRectGetHeight(rect)) / 2.0;
    CGFloat angleIncrement = 2.0 * M_PI / 5.0;
    CGFloat startAngle = -M_PI_2; // 从顶部开始
    
    for (int i = 0; i < 5; i++) {
        CGFloat angle = startAngle + i * angleIncrement;
        CGPoint point = CGPointMake(centerX + radius * cos(angle), centerY + radius * sin(angle));
        
        if (i == 0) {
            [self.currentPath moveToPoint:point];
        } else {
            [self.currentPath addLineToPoint:point];
        }
    }
    [self.currentPath closePath];
}

- (void)drawTrapezoidInRect:(CGRect)rect {
    [self.currentPath removeAllPoints];
    if (CGRectIsEmpty(rect)) return;
    
    CGFloat topWidth = CGRectGetWidth(rect) * 0.6; // 上边比下边短
    CGFloat bottomWidth = CGRectGetWidth(rect);
    CGFloat height = CGRectGetHeight(rect);
    
    CGFloat centerX = CGRectGetMidX(rect);
    CGFloat topY = CGRectGetMinY(rect);
    CGFloat bottomY = CGRectGetMaxY(rect);
    
    // 梯形的四个顶点
    CGPoint topLeft = CGPointMake(centerX - topWidth / 2.0, topY);
    CGPoint topRight = CGPointMake(centerX + topWidth / 2.0, topY);
    CGPoint bottomRight = CGPointMake(centerX + bottomWidth / 2.0, bottomY);
    CGPoint bottomLeft = CGPointMake(centerX - bottomWidth / 2.0, bottomY);
    
    [self.currentPath moveToPoint:topLeft];
    [self.currentPath addLineToPoint:topRight];
    [self.currentPath addLineToPoint:bottomRight];
    [self.currentPath addLineToPoint:bottomLeft];
    [self.currentPath closePath];
}

- (void)drawDiamondInRect:(CGRect)rect {
    [self.currentPath removeAllPoints];
    if (CGRectIsEmpty(rect)) return;
    
    CGFloat centerX = CGRectGetMidX(rect);
    CGFloat centerY = CGRectGetMidY(rect);
    CGFloat halfWidth = CGRectGetWidth(rect) / 2.0;
    CGFloat halfHeight = CGRectGetHeight(rect) / 2.0;
    
    // 菱形的四个顶点
    CGPoint top = CGPointMake(centerX, centerY - halfHeight);
    CGPoint right = CGPointMake(centerX + halfWidth, centerY);
    CGPoint bottom = CGPointMake(centerX, centerY + halfHeight);
    CGPoint left = CGPointMake(centerX - halfWidth, centerY);
    
    [self.currentPath moveToPoint:top];
    [self.currentPath addLineToPoint:right];
    [self.currentPath addLineToPoint:bottom];
    [self.currentPath addLineToPoint:left];
    [self.currentPath closePath];
}

- (void)drawCoordinateSystemInRect:(CGRect)rect {
    [self.currentPath removeAllPoints];
    if (CGRectIsEmpty(rect)) return;
    
    CGFloat centerX = CGRectGetMidX(rect);
    CGFloat centerY = CGRectGetMidY(rect);
    CGFloat margin = 20.0;
    
    // X轴
    [self.currentPath moveToPoint:CGPointMake(CGRectGetMinX(rect) + margin, centerY)];
    [self.currentPath addLineToPoint:CGPointMake(CGRectGetMaxX(rect) - margin, centerY)];
    
    // X轴箭头
    CGFloat arrowSize = 8.0;
    CGPoint xArrowTip = CGPointMake(CGRectGetMaxX(rect) - margin, centerY);
    [self.currentPath addLineToPoint:CGPointMake(xArrowTip.x - arrowSize, xArrowTip.y - arrowSize/2)];
    [self.currentPath moveToPoint:xArrowTip];
    [self.currentPath addLineToPoint:CGPointMake(xArrowTip.x - arrowSize, xArrowTip.y + arrowSize/2)];
    
    // Y轴
    [self.currentPath moveToPoint:CGPointMake(centerX, CGRectGetMaxY(rect) - margin)];
    [self.currentPath addLineToPoint:CGPointMake(centerX, CGRectGetMinY(rect) + margin)];
    
    // Y轴箭头
    CGPoint yArrowTip = CGPointMake(centerX, CGRectGetMinY(rect) + margin);
    [self.currentPath addLineToPoint:CGPointMake(yArrowTip.x - arrowSize/2, yArrowTip.y + arrowSize)];
    [self.currentPath moveToPoint:yArrowTip];
    [self.currentPath addLineToPoint:CGPointMake(yArrowTip.x + arrowSize/2, yArrowTip.y + arrowSize)];
    
    // 添加刻度线
    CGFloat tickSize = 4.0;
    CGFloat tickSpacing = 20.0;
    
    // X轴刻度
    for (CGFloat x = centerX + tickSpacing; x < CGRectGetMaxX(rect) - margin; x += tickSpacing) {
        [self.currentPath moveToPoint:CGPointMake(x, centerY - tickSize)];
        [self.currentPath addLineToPoint:CGPointMake(x, centerY + tickSize)];
    }
    for (CGFloat x = centerX - tickSpacing; x > CGRectGetMinX(rect) + margin; x -= tickSpacing) {
        [self.currentPath moveToPoint:CGPointMake(x, centerY - tickSize)];
        [self.currentPath addLineToPoint:CGPointMake(x, centerY + tickSize)];
    }
    
    // Y轴刻度
    for (CGFloat y = centerY + tickSpacing; y < CGRectGetMaxY(rect) - margin; y += tickSpacing) {
        [self.currentPath moveToPoint:CGPointMake(centerX - tickSize, y)];
        [self.currentPath addLineToPoint:CGPointMake(centerX + tickSize, y)];
    }
    for (CGFloat y = centerY - tickSpacing; y > CGRectGetMinY(rect) + margin; y -= tickSpacing) {
        [self.currentPath moveToPoint:CGPointMake(centerX - tickSize, y)];
        [self.currentPath addLineToPoint:CGPointMake(centerX + tickSize, y)];
    }
}

- (void)drawPyramidInRect:(CGRect)rect {
    [self.currentPath removeAllPoints];
    if (CGRectIsEmpty(rect)) return;
    
    CGFloat width = CGRectGetWidth(rect);
    CGFloat height = CGRectGetHeight(rect);
    CGFloat centerX = CGRectGetMidX(rect);
    
    // 三棱锥的顶点
    CGPoint apex = CGPointMake(centerX, CGRectGetMinY(rect));
    
    // 底面三角形的三个顶点
    CGFloat baseY = CGRectGetMaxY(rect);
    CGFloat baseRadius = width * 0.4;
    CGPoint base1 = CGPointMake(centerX, baseY - baseRadius * 0.3);
    CGPoint base2 = CGPointMake(centerX - baseRadius * 0.8, baseY);
    CGPoint base3 = CGPointMake(centerX + baseRadius * 0.8, baseY);
    
    // 绘制可见的边
    [self.currentPath moveToPoint:apex];
    [self.currentPath addLineToPoint:base1];
    [self.currentPath addLineToPoint:base2];
    [self.currentPath addLineToPoint:base3];
    [self.currentPath addLineToPoint:base1];
    
    [self.currentPath moveToPoint:apex];
    [self.currentPath addLineToPoint:base2];
    
    [self.currentPath moveToPoint:apex];
    [self.currentPath addLineToPoint:base3];
}

- (void)drawConeInRect:(CGRect)rect {
    [self.currentPath removeAllPoints];
    if (CGRectIsEmpty(rect)) return;
    
    CGFloat centerX = CGRectGetMidX(rect);
    CGFloat height = CGRectGetHeight(rect);
    CGFloat baseRadius = CGRectGetWidth(rect) * 0.4;
    
    // 圆锥顶点
    CGPoint apex = CGPointMake(centerX, CGRectGetMinY(rect));
    
    // 底面椭圆
    CGFloat baseY = CGRectGetMaxY(rect);
    CGFloat ellipseHeight = baseRadius * 0.3; // 椭圆的高度（透视效果）
    
    // 绘制底面椭圆
    CGRect ellipseRect = CGRectMake(centerX - baseRadius, baseY - ellipseHeight, 
                                   baseRadius * 2, ellipseHeight * 2);
    UIBezierPath *ellipse = [UIBezierPath bezierPathWithOvalInRect:ellipseRect];
    [self.currentPath appendPath:ellipse];
    
    // 绘制圆锥的侧面轮廓线
    [self.currentPath moveToPoint:apex];
    [self.currentPath addLineToPoint:CGPointMake(centerX - baseRadius, baseY)];
    
    [self.currentPath moveToPoint:apex];
    [self.currentPath addLineToPoint:CGPointMake(centerX + baseRadius, baseY)];
}

- (void)drawCylinderInRect:(CGRect)rect {
    [self.currentPath removeAllPoints];
    if (CGRectIsEmpty(rect)) return;
    
    CGFloat centerX = CGRectGetMidX(rect);
    CGFloat width = CGRectGetWidth(rect);
    CGFloat height = CGRectGetHeight(rect);
    CGFloat radius = width * 0.4;
    CGFloat ellipseHeight = radius * 0.3; // 椭圆的高度（透视效果）
    
    // 顶面椭圆
    CGRect topEllipseRect = CGRectMake(centerX - radius, CGRectGetMinY(rect), 
                                      radius * 2, ellipseHeight * 2);
    UIBezierPath *topEllipse = [UIBezierPath bezierPathWithOvalInRect:topEllipseRect];
    [self.currentPath appendPath:topEllipse];
    
    // 底面椭圆
    CGRect bottomEllipseRect = CGRectMake(centerX - radius, CGRectGetMaxY(rect) - ellipseHeight * 2, 
                                         radius * 2, ellipseHeight * 2);
    UIBezierPath *bottomEllipse = [UIBezierPath bezierPathWithOvalInRect:bottomEllipseRect];
    [self.currentPath appendPath:bottomEllipse];
    
    // 侧面的两条竖直线
    [self.currentPath moveToPoint:CGPointMake(centerX - radius, CGRectGetMinY(rect) + ellipseHeight)];
    [self.currentPath addLineToPoint:CGPointMake(centerX - radius, CGRectGetMaxY(rect) - ellipseHeight)];
    
    [self.currentPath moveToPoint:CGPointMake(centerX + radius, CGRectGetMinY(rect) + ellipseHeight)];
    [self.currentPath addLineToPoint:CGPointMake(centerX + radius, CGRectGetMaxY(rect) - ellipseHeight)];
}

- (void)drawCubeInRect:(CGRect)rect {
    [self.currentPath removeAllPoints];
    if (CGRectIsEmpty(rect)) return;
    
    CGFloat size = MIN(CGRectGetWidth(rect), CGRectGetHeight(rect));
    CGFloat offset = size * 0.25; // 透视偏移
    
    CGFloat centerX = CGRectGetMidX(rect);
    CGFloat centerY = CGRectGetMidY(rect);
    CGFloat halfSize = size * 0.35;
    
    // 前面正方形的四个顶点
    CGPoint frontTL = CGPointMake(centerX - halfSize, centerY - halfSize);
    CGPoint frontTR = CGPointMake(centerX + halfSize, centerY - halfSize);
    CGPoint frontBL = CGPointMake(centerX - halfSize, centerY + halfSize);
    CGPoint frontBR = CGPointMake(centerX + halfSize, centerY + halfSize);
    
    // 后面正方形的四个顶点（添加透视偏移）
    CGPoint backTL = CGPointMake(frontTL.x + offset, frontTL.y - offset);
    CGPoint backTR = CGPointMake(frontTR.x + offset, frontTR.y - offset);
    CGPoint backBL = CGPointMake(frontBL.x + offset, frontBL.y - offset);
    CGPoint backBR = CGPointMake(frontBR.x + offset, frontBR.y - offset);
    
    // 绘制前面正方形
    [self.currentPath moveToPoint:frontTL];
    [self.currentPath addLineToPoint:frontTR];
    [self.currentPath addLineToPoint:frontBR];
    [self.currentPath addLineToPoint:frontBL];
    [self.currentPath closePath];
    
    // 绘制后面正方形（部分可见）
    [self.currentPath moveToPoint:backTL];
    [self.currentPath addLineToPoint:backTR];
    [self.currentPath addLineToPoint:backBR];
    
    // 绘制连接线（显示立体效果）
    [self.currentPath moveToPoint:frontTL];
    [self.currentPath addLineToPoint:backTL];
    
    [self.currentPath moveToPoint:frontTR];
    [self.currentPath addLineToPoint:backTR];
    
    [self.currentPath moveToPoint:frontBR];
    [self.currentPath addLineToPoint:backBR];
}

@end
