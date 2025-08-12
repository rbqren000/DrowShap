#import <UIKit/UIKit.h>
#import "DrawingBoardView.h"

@interface ViewController : UIViewController <UINavigationControllerDelegate, UIImagePickerControllerDelegate>

@property (nonatomic, strong) DrawingBoardView *drawingBoard;

// 新增：用于可伸缩菜单的UI组件
@property (nonatomic, strong) UIButton *currentToolButton;
@property (nonatomic, strong) UIStackView *toolOptionsContainer;

@end
