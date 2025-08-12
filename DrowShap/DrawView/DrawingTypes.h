#ifndef DrawingTypes_h
#define DrawingTypes_h

#import <Foundation/Foundation.h>

// 定义绘图形状的类型
// 定义绘图形状的类型
typedef NS_ENUM(NSInteger, DrawingToolType) {
    // 基础绘图工具
    DrawingToolTypePen,         // 自由画笔
    DrawingToolTypeLine,        // 直线
    DrawingToolTypeArrow,       // 箭头
    DrawingToolTypeTextBox,     // 文本框
    
    // 基本几何图形
    DrawingToolTypeRectangle,   // 矩形
    DrawingToolTypeOval,        // 椭圆
    DrawingToolTypeCircle,      // 正圆形
    DrawingToolTypeTriangle,    // 三角形
    DrawingToolTypePentagon,    // 五边形
    DrawingToolTypeTrapezoid,   // 梯形
    DrawingToolTypeDiamond,     // 菱形
    DrawingToolTypeStar,        // 五角星
    
    // 数学图形
    DrawingToolTypeSineWave,    // 正弦波
    DrawingToolTypeCosineWave,  // 余弦波
    DrawingToolTypeCoordinateSystem, // 直角坐标系
    
    // 立体图形
    DrawingToolTypePyramid,     // 三棱锥
    DrawingToolTypeCone,        // 圆锥
    DrawingToolTypeCylinder,    // 圆柱
    DrawingToolTypeCube,        // 立方体
    
    // 操作工具（放在最后）
    DrawingToolTypeSelector,    // 选择工具
    DrawingToolTypeEraser,      // 橡皮擦
};

#endif /* DrawingTypes_h */
