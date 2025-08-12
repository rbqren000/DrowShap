# DrawView 绘图模块

DrawView是一个功能完整的iOS绘图框架，支持多种绘图工具、图像缩放、撤销重做等功能。

## 模块结构

```
DrowShap/
├── DrawView/
│   ├── DrawingBoardView.h/.m     # 主绘图面板，集成缩放和绘图功能
│   ├── DrawingView.h/.m          # 核心绘图视图，处理触摸事件和绘图逻辑
│   ├── DrawingShape.h/.m         # 图形对象模型
│   ├── DrawingText.h/.m          # 文本对象模型
│   └── DrawingTypes.h            # 绘图工具类型定义
└── README.md                     # 项目文档
```

## 核心组件

### DrawingBoardView
主绘图面板，是整个绘图模块的入口组件。

**主要功能：**
- 集成UIScrollView实现图像缩放功能
- 管理背景图片显示
- 统一的绘图工具接口
- 支持缩放模式和绘图模式切换

**关键属性：**
```objc
@property (nonatomic, assign) DrawingToolType currentTool;      // 当前绘图工具
@property (nonatomic, strong) UIColor *strokeColor;            // 描边颜色
@property (nonatomic, strong) UIColor *fillColor;              // 填充颜色
@property (nonatomic, assign) CGFloat lineWidth;               // 线宽
@property (nonatomic, assign) BOOL zoomEnabled;                // 是否启用缩放
```

**主要方法：**
```objc
// 设置背景图片
- (void)setupWithImage:(UIImage *)image;

// 撤销/重做操作
- (void)undo;
- (void)redo;

// 清除绘图
- (void)clearDrawing;
- (void)restoreAllDrawing;

// 导出绘图结果
- (UIImage *)captureDrawing;
- (UIImage *)captureDrawingWithOriginalSize;
```

### DrawingView
核心绘图视图，负责处理所有绘图操作。

**主要功能：**
- 处理触摸事件和手势识别
- 管理绘图对象的创建和编辑
- 实现撤销/重做机制
- 支持对象选择和属性编辑

**绘图工具支持：**
- 自由画笔
- 直线
- 矩形
- 圆形/椭圆
- 文本输入
- 选择工具

### DrawingShape
图形对象模型，表示各种几何图形。

**支持的图形类型：**
- 自由路径（画笔）
- 直线
- 矩形
- 圆形/椭圆

**属性：**
```objc
@property (nonatomic, strong) UIBezierPath *path;              // 图形路径
@property (nonatomic, strong) UIColor *strokeColor;            // 描边颜色
@property (nonatomic, strong) UIColor *fillColor;              // 填充颜色
@property (nonatomic, assign) CGFloat lineWidth;               // 线宽
@property (nonatomic, copy) NSArray<NSNumber *> *lineDashPattern; // 虚线样式
```

### DrawingText
文本对象模型，表示文本元素。

**属性：**
```objc
@property (nonatomic, strong) NSString *text;                  // 文本内容
@property (nonatomic, assign) CGPoint origin;                  // 文本位置
@property (nonatomic, strong) NSDictionary *attributes;        // 文本属性
```

## 使用方法

### 基本使用

```objc
// 1. 创建绘图面板
DrawingBoardView *drawingBoard = [[DrawingBoardView alloc] initWithFrame:self.view.bounds];
drawingBoard.delegate = self;
[self.view addSubview:drawingBoard];

// 2. 设置背景图片
UIImage *backgroundImage = [UIImage imageNamed:@"background.jpg"];
[drawingBoard setupWithImage:backgroundImage];

// 3. 配置绘图工具
drawingBoard.currentTool = DrawingToolTypePen;
drawingBoard.strokeColor = [UIColor redColor];
drawingBoard.lineWidth = 3.0;
```

### 工具切换

```objc
// 切换到画笔工具
drawingBoard.currentTool = DrawingToolTypePen;

// 切换到矩形工具
drawingBoard.currentTool = DrawingToolTypeRectangle;

// 切换到文本工具
drawingBoard.currentTool = DrawingToolTypeText;
drawingBoard.fontSize = 18.0;

// 启用缩放模式（禁用绘图）
drawingBoard.zoomEnabled = YES;
```

### 颜色和样式设置

```objc
// 设置描边颜色
drawingBoard.strokeColor = [UIColor blueColor];

// 设置填充颜色
drawingBoard.fillColor = [UIColor colorWithRed:0.5 green:0.8 blue:1.0 alpha:0.3];

// 设置虚线样式
drawingBoard.lineDashPattern = @[@5, @3]; // 5像素实线，3像素空白

// 设置线宽
drawingBoard.lineWidth = 2.0;
```

### 撤销和重做

```objc
// 检查是否可以撤销/重做
if (drawingBoard.canUndo) {
    [drawingBoard undo];
}

if (drawingBoard.canRedo) {
    [drawingBoard redo];
}

// 清除所有绘图
[drawingBoard clearDrawing];

// 恢复所有绘图
[drawingBoard restoreAllDrawing];
```

### 导出绘图结果

```objc
// 导出当前显示尺寸的图片
UIImage *currentImage = [drawingBoard captureDrawing];

// 导出原始尺寸的图片（推荐用于保存）
UIImage *originalSizeImage = [drawingBoard captureDrawingWithOriginalSize];
```

### 委托方法

```objc
// 实现委托协议
@interface ViewController : UIViewController <DrawingBoardViewDelegate>
@end

@implementation ViewController

- (void)drawingBoardView:(DrawingBoardView *)boardView didSelectItem:(id)item {
    // 处理绘图对象选择事件
    if ([item isKindOfClass:[DrawingShape class]]) {
        DrawingShape *shape = (DrawingShape *)item;
        NSLog(@"选中了图形，颜色：%@", shape.strokeColor);
    } else if ([item isKindOfClass:[DrawingText class]]) {
        DrawingText *text = (DrawingText *)item;
        NSLog(@"选中了文本：%@", text.text);
    }
}

@end
```

## 高级功能

### 图像坐标变换
当背景图片尺寸发生变化时，绘图内容会自动按比例调整：

```objc
// 更换背景图片时，现有绘图会自动适配新尺寸
UIImage *newImage = [UIImage imageNamed:@"new_background.jpg"];
[drawingBoard setupWithImage:newImage];
```

### 精确的原始尺寸导出
`captureDrawingWithOriginalSize`方法提供了高质量的图片导出功能：

- 直接基于背景图片的原始像素尺寸
- 绘图内容精确映射到原始坐标系
- 支持高分辨率图片处理
- 保持图片的原始scale属性

### 缩放和绘图模式切换
通过`zoomEnabled`属性可以在缩放模式和绘图模式之间切换：

- `zoomEnabled = YES`：启用缩放，禁用绘图
- `zoomEnabled = NO`：禁用缩放，启用绘图

## 绘图工具类型

```objc
typedef NS_ENUM(NSInteger, DrawingToolType) {
    DrawingToolTypeNone = 0,        // 无工具
    DrawingToolTypePen,             // 画笔
    DrawingToolTypeLine,            // 直线
    DrawingToolTypeRectangle,       // 矩形
    DrawingToolTypeCircle,          // 圆形
    DrawingToolTypeText,            // 文本
    DrawingToolTypeSelect           // 选择工具
};
```

## 注意事项

1. **内存管理**：绘图过程中会创建大量的图形对象，建议在适当时机调用`clearDrawing`清理不需要的绘图数据。

2. **性能优化**：对于大尺寸图片，建议使用`captureDrawingWithOriginalSize`而不是`captureDrawing`来获得更好的性能和质量。

3. **线程安全**：所有UI操作必须在主线程进行，包括绘图操作和图片导出。

4. **坐标系统**：绘图坐标基于UIKit坐标系，原点在左上角。

5. **缩放限制**：缩放范围自动根据图片尺寸和视图尺寸计算，确保图片始终可见。

## 扩展开发

如需添加新的绘图工具，可以：

1. 在`DrawingTypes.h`中添加新的工具类型
2. 在`DrawingView.m`中实现对应的触摸处理逻辑
3. 如需要，创建新的绘图对象模型类

## 版本历史

- v1.0：基础绘图功能
- v1.1：添加文本支持和填充颜色
- v1.2：添加虚线样式和选择工具
- v1.3：优化原始尺寸导出功能
- v1.4：改进坐标变换和内存管理