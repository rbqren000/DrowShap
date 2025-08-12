#import "ViewController.h"
#import "DrawingShape.h"
#import "DrawingText.h"

#pragma mark - ColorButton Custom Class

@interface ColorButton : UIButton
@property (nonatomic, assign) BOOL isColorSelected;
@end

@implementation ColorButton
- (void)setIsColorSelected:(BOOL)isColorSelected {
    _isColorSelected = isColorSelected;
    if (isColorSelected) {
        self.layer.borderColor = [UIColor systemBlueColor].CGColor;
        self.layer.borderWidth = 3.0;
        self.transform = CGAffineTransformMakeScale(1.1, 1.1);
    } else {
        self.layer.borderColor = [UIColor whiteColor].CGColor;
        self.layer.borderWidth = 2.0;
        self.transform = CGAffineTransformIdentity;
    }
}
@end


#pragma mark - ViewController Implementation

@interface ViewController () <DrawingBoardViewDelegate>

@property (nonatomic, strong) UISegmentedControl *colorModeSelector;
@property (nonatomic, strong) UISwitch *zoomSwitch;
@property (nonatomic, strong) UILabel *zoomLabel;
@property (nonatomic, strong) UISlider *widthSlider;
@property (nonatomic, strong) UISlider *fontSizeSlider;
@property (nonatomic, strong) UIStackView *mainStackView;
@property (nonatomic, strong) UIStackView *colorStack;
@property (nonatomic, strong) UISegmentedControl *lineStyleSelector;
@property (nonatomic, strong) ColorButton *selectedColorButton;
@property (nonatomic, strong) UIAlertController *currentAlert; // 防止多个Alert同时显示

@end

@implementation ViewController

- (void)viewDidLoad {
    [super viewDidLoad];
    self.view.backgroundColor = [UIColor colorWithWhite:0.9 alpha:1.0];
    self.title = @"Drawing Board";

    self.drawingBoard = [[DrawingBoardView alloc] init];
    self.drawingBoard.translatesAutoresizingMaskIntoConstraints = NO;
    self.drawingBoard.delegate = self; // 设置委托
    [self.view addSubview:self.drawingBoard];

    [self setupToolbar];
    [self setupLayoutConstraints];
    [self loadDefaultImage];
}

- (void)setupToolbar {
    // --- 可伸缩工具菜单 ---
    self.currentToolButton = [self createCompactToolbarButtonWithTitle:@"Pen" action:@selector(toggleToolMenu)];
    
    NSArray *toolNames = @[@"Pen", @"Line", @"Arrow", @"Text", @"Rect", @"Oval", @"Circle", @"Tri", @"Pentagon", @"Trapezoid", @"Diamond", @"Star", @"Sine", @"Cosine", @"Coordinate", @"Pyramid", @"Cone", @"Cylinder", @"Cube", @"Selector", @"Eraser"];
    
    // 将工具按钮分成3列布局以节省空间
    NSMutableArray<UIStackView *> *toolRows = [NSMutableArray array];
    for (int i = 0; i < toolNames.count; i += 3) {
        NSMutableArray *rowButtons = [NSMutableArray array];
        for (int j = 0; j < 3 && (i + j) < toolNames.count; j++) {
            UIButton *button = [self createCompactToolbarButtonWithTitle:toolNames[i + j] action:@selector(toolSelected:)];
            button.tag = i + j;
            [rowButtons addObject:button];
        }
        
        UIStackView *rowStack = [[UIStackView alloc] initWithArrangedSubviews:rowButtons];
        rowStack.axis = UILayoutConstraintAxisHorizontal;
        rowStack.spacing = 4;
        rowStack.distribution = UIStackViewDistributionFillEqually;
        [toolRows addObject:rowStack];
    }
    
    self.toolOptionsContainer = [[UIStackView alloc] initWithArrangedSubviews:toolRows];
    self.toolOptionsContainer.axis = UILayoutConstraintAxisVertical;
    self.toolOptionsContainer.spacing = 4;
    self.toolOptionsContainer.hidden = YES;

    UIStackView *toolMenuStack = [[UIStackView alloc] initWithArrangedSubviews:@[self.currentToolButton, self.toolOptionsContainer]];
    toolMenuStack.axis = UILayoutConstraintAxisVertical;
    toolMenuStack.spacing = 6;
    // --- 菜单结束 ---

    // 合并颜色模式和填充选项到一行
    self.colorModeSelector = [[UISegmentedControl alloc] initWithItems:@[@"Stroke", @"Fill"]];
    self.colorModeSelector.selectedSegmentIndex = 0;
    [self.colorModeSelector addTarget:self action:@selector(colorModeChanged:) forControlEvents:UIControlEventValueChanged];
    
    UIButton *noFillButton = [self createCompactToolbarButtonWithTitle:@"No Fill" action:@selector(clearFillColorTapped)];
    UIStackView *fillOptionsStack = [[UIStackView alloc] initWithArrangedSubviews:@[self.colorModeSelector, noFillButton]];
    fillOptionsStack.spacing = 6;
    fillOptionsStack.distribution = UIStackViewDistributionFill;

    // 颜色选择器保持紧凑
    NSArray *colors = @[[UIColor blackColor], [UIColor redColor], [UIColor blueColor], [UIColor greenColor], [UIColor yellowColor], [UIColor orangeColor], [UIColor purpleColor], [UIColor brownColor]];
    NSMutableArray *colorButtons = [NSMutableArray array];
    for (UIColor *color in colors) {
        ColorButton *button = [self createCompactColorButtonWithColor:color];
        [colorButtons addObject:button];
    }
    self.colorStack = [[UIStackView alloc] initWithArrangedSubviews:colorButtons];
    self.colorStack.spacing = 6;
    self.colorStack.distribution = UIStackViewDistributionEqualSpacing;
    
    self.selectedColorButton = colorButtons.firstObject;
    self.selectedColorButton.isColorSelected = YES;
    self.drawingBoard.strokeColor = self.selectedColorButton.backgroundColor;
    self.drawingBoard.fillColor = nil;

    // 合并滑块和线条样式到一行
    UILabel *widthLabel = [[UILabel alloc] init];
    widthLabel.text = @"Width:";
    widthLabel.font = [UIFont systemFontOfSize:12];
    [widthLabel setContentHuggingPriority:UILayoutPriorityRequired forAxis:UILayoutConstraintAxisHorizontal];
    
    self.widthSlider = [[UISlider alloc] init];
    self.widthSlider.minimumValue = 1.0;
    self.widthSlider.maximumValue = 30.0;
    self.widthSlider.value = 2.0;
    [self.widthSlider addTarget:self action:@selector(widthChanged:) forControlEvents:UIControlEventValueChanged];
    
    self.lineStyleSelector = [[UISegmentedControl alloc] initWithItems:@[@"Solid", @"Dash"]];
    self.lineStyleSelector.selectedSegmentIndex = 0;
    [self.lineStyleSelector addTarget:self action:@selector(lineStyleChanged:) forControlEvents:UIControlEventValueChanged];
    [self.lineStyleSelector setContentHuggingPriority:UILayoutPriorityRequired forAxis:UILayoutConstraintAxisHorizontal];
    
    UIStackView *widthLineStack = [[UIStackView alloc] initWithArrangedSubviews:@[widthLabel, self.widthSlider, self.lineStyleSelector]];
    widthLineStack.spacing = 6;
    widthLineStack.alignment = UIStackViewAlignmentCenter;

    // 字体大小滑块
    UILabel *fontLabel = [[UILabel alloc] init];
    fontLabel.text = @"Font:";
    fontLabel.font = [UIFont systemFontOfSize:12];
    [fontLabel setContentHuggingPriority:UILayoutPriorityRequired forAxis:UILayoutConstraintAxisHorizontal];
    
    self.fontSizeSlider = [[UISlider alloc] init];
    self.fontSizeSlider.minimumValue = 12.0;
    self.fontSizeSlider.maximumValue = 60.0;
    self.fontSizeSlider.value = 24.0;
    [self.fontSizeSlider addTarget:self action:@selector(fontSizeChanged:) forControlEvents:UIControlEventValueChanged];
    
    UIStackView *fontStack = [[UIStackView alloc] initWithArrangedSubviews:@[fontLabel, self.fontSizeSlider]];
    fontStack.spacing = 6;
    fontStack.hidden = YES;

    // 合并所有操作按钮到两行
    UIButton *undoButton = [self createCompactToolbarButtonWithTitle:@"Undo" action:@selector(undoTapped)];
    UIButton *redoButton = [self createCompactToolbarButtonWithTitle:@"Redo" action:@selector(redoTapped)];
    UIButton *clearButton = [self createCompactToolbarButtonWithTitle:@"Clear" action:@selector(clearTapped)];
    UIButton *restoreButton = [self createCompactToolbarButtonWithTitle:@"Restore" action:@selector(restoreTapped)];
    UIButton *saveButton = [self createCompactToolbarButtonWithTitle:@"Save" action:@selector(saveTapped)];
    UIButton *selectImageButton = [self createCompactToolbarButtonWithTitle:@"Image" action:@selector(selectImageTapped)];
    
    UIStackView *actionStack1 = [[UIStackView alloc] initWithArrangedSubviews:@[undoButton, redoButton, clearButton, restoreButton]];
    actionStack1.spacing = 4;
    actionStack1.distribution = UIStackViewDistributionFillEqually;
    
    UIStackView *actionStack2 = [[UIStackView alloc] initWithArrangedSubviews:@[saveButton, selectImageButton]];
    actionStack2.spacing = 4;
    actionStack2.distribution = UIStackViewDistributionFillEqually;

    // 缩放开关更紧凑
    self.zoomSwitch = [[UISwitch alloc] init];
    self.zoomSwitch.transform = CGAffineTransformMakeScale(0.8, 0.8); // 缩小开关
    [self.zoomSwitch addTarget:self action:@selector(zoomSwitchChanged:) forControlEvents:UIControlEventValueChanged];
    self.zoomLabel = [[UILabel alloc] init];
    self.zoomLabel.text = @"Zoom";
    self.zoomLabel.font = [UIFont systemFontOfSize:12];
    UIStackView *zoomStack = [[UIStackView alloc] initWithArrangedSubviews:@[self.zoomLabel, self.zoomSwitch]];
    zoomStack.spacing = 6;
    zoomStack.alignment = UIStackViewAlignmentCenter;

    // 将操作按钮和缩放开关合并到一行
    UIStackView *bottomControlsStack = [[UIStackView alloc] initWithArrangedSubviews:@[actionStack2, zoomStack]];
    bottomControlsStack.spacing = 8;
    bottomControlsStack.distribution = UIStackViewDistributionFill;

    self.mainStackView = [[UIStackView alloc] initWithArrangedSubviews:@[toolMenuStack, fillOptionsStack, self.colorStack, widthLineStack, fontStack, actionStack1, bottomControlsStack]];
    self.mainStackView.axis = UILayoutConstraintAxisVertical;
    self.mainStackView.spacing = 8; // 减少间距
    self.mainStackView.translatesAutoresizingMaskIntoConstraints = NO;
    self.mainStackView.backgroundColor = [UIColor colorWithWhite:1.0 alpha:0.9];
    self.mainStackView.layer.cornerRadius = 8;
    self.mainStackView.layoutMargins = UIEdgeInsetsMake(8, 8, 8, 8); // 减少内边距
    [self.mainStackView setLayoutMarginsRelativeArrangement:YES];
    [self.view addSubview:self.mainStackView];
}

- (void)setupLayoutConstraints {
    [NSLayoutConstraint activateConstraints:@[
        // DrawingBoard 约束到安全区域，并为底部工具栏留出空间
        [self.drawingBoard.topAnchor constraintEqualToAnchor:self.view.safeAreaLayoutGuide.topAnchor],
        [self.drawingBoard.leadingAnchor constraintEqualToAnchor:self.view.safeAreaLayoutGuide.leadingAnchor],
        [self.drawingBoard.trailingAnchor constraintEqualToAnchor:self.view.safeAreaLayoutGuide.trailingAnchor],
        [self.drawingBoard.bottomAnchor constraintEqualToAnchor:self.mainStackView.topAnchor constant:-8],

        // 工具栏约束
        [self.mainStackView.leadingAnchor constraintEqualToAnchor:self.view.safeAreaLayoutGuide.leadingAnchor constant:8],
        [self.mainStackView.trailingAnchor constraintEqualToAnchor:self.view.safeAreaLayoutGuide.trailingAnchor constant:-8],
        [self.mainStackView.bottomAnchor constraintEqualToAnchor:self.view.safeAreaLayoutGuide.bottomAnchor constant:-8]
    ]];
}

- (void)loadDefaultImage {
    UIImage *imageToDrawOn = [UIImage imageNamed:@"sample_image"];
    if (imageToDrawOn) {
        [self.drawingBoard setupWithImage:imageToDrawOn];
    } else {
        UIGraphicsBeginImageContext(CGSizeMake(1024, 1024));
        [[UIColor whiteColor] setFill];
        UIRectFill(CGRectMake(0, 0, 1024, 1024));
        UIImage *blankImage = UIGraphicsGetImageFromCurrentImageContext();
        UIGraphicsEndImageContext();
        [self.drawingBoard setupWithImage:blankImage];
    }
}

#pragma mark - UI Helpers

- (UIButton *)createToolbarButtonWithTitle:(NSString *)title action:(SEL)action {
    UIButton *button = [UIButton buttonWithType:UIButtonTypeSystem];
    [button setTitle:title forState:UIControlStateNormal];
    [button addTarget:self action:action forControlEvents:UIControlEventTouchUpInside];
    button.backgroundColor = [UIColor whiteColor];
    button.layer.borderWidth = 1.0;
    button.layer.borderColor = [UIColor grayColor].CGColor;
    button.layer.cornerRadius = 5;
    [button setContentEdgeInsets:UIEdgeInsetsMake(8, 12, 8, 12)];
    return button;
}

- (UIButton *)createCompactToolbarButtonWithTitle:(NSString *)title action:(SEL)action {
    UIButton *button = [UIButton buttonWithType:UIButtonTypeSystem];
    [button setTitle:title forState:UIControlStateNormal];
    [button addTarget:self action:action forControlEvents:UIControlEventTouchUpInside];
    button.backgroundColor = [UIColor whiteColor];
    button.layer.borderWidth = 0.5;
    button.layer.borderColor = [UIColor lightGrayColor].CGColor;
    button.layer.cornerRadius = 4;
    button.titleLabel.font = [UIFont systemFontOfSize:12];
    [button setContentEdgeInsets:UIEdgeInsetsMake(4, 6, 4, 6)];
    [button.heightAnchor constraintEqualToConstant:28].active = YES;
    return button;
}

- (ColorButton *)createColorButtonWithColor:(UIColor *)color {
    ColorButton *button = [ColorButton buttonWithType:UIButtonTypeCustom];
    button.backgroundColor = color;
    button.layer.cornerRadius = 15;
    [button addTarget:self action:@selector(changeColor:) forControlEvents:UIControlEventTouchUpInside];
    [button.heightAnchor constraintEqualToConstant:30].active = YES;
    [button.widthAnchor constraintEqualToConstant:30].active = YES;
    button.isColorSelected = NO;
    return button;
}

- (ColorButton *)createCompactColorButtonWithColor:(UIColor *)color {
    ColorButton *button = [ColorButton buttonWithType:UIButtonTypeCustom];
    button.backgroundColor = color;
    button.layer.cornerRadius = 12;
    [button addTarget:self action:@selector(changeColor:) forControlEvents:UIControlEventTouchUpInside];
    [button.heightAnchor constraintEqualToConstant:24].active = YES;
    [button.widthAnchor constraintEqualToConstant:24].active = YES;
    button.isColorSelected = NO;
    return button;
}

#pragma mark - Actions

- (void)toggleToolMenu {
    [UIView animateWithDuration:0.3 animations:^{
        self.toolOptionsContainer.hidden = !self.toolOptionsContainer.hidden;
    }];
}

- (void)toolSelected:(UIButton *)sender {
    DrawingToolType selectedTool = (DrawingToolType)sender.tag;
    self.drawingBoard.currentTool = selectedTool;
    [self.currentToolButton setTitle:sender.titleLabel.text forState:UIControlStateNormal];

    // Determine which controls to show based on the selected tool
    BOOL showColor = NO;
    BOOL showWidth = NO;
    BOOL showLineStyle = NO;
    BOOL showFontSize = NO;

    switch (selectedTool) {
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
            showColor = YES;
            showWidth = YES;
            showLineStyle = YES;
            break;
        case DrawingToolTypeTextBox:
            showColor = YES;
            showFontSize = YES;
            break;
        case DrawingToolTypeEraser:
        case DrawingToolTypeSelector:
            // No controls shown for these tools
            break;
    }

    // Apply visibility
    self.colorModeSelector.superview.hidden = !showColor;
    self.colorStack.hidden = !showColor;
    self.widthSlider.superview.hidden = !showWidth;
    self.lineStyleSelector.hidden = !showLineStyle;
    self.fontSizeSlider.superview.hidden = !showFontSize;

    [self toggleToolMenu]; // Close menu after selection
}

- (void)changeColor:(ColorButton *)sender {
    self.selectedColorButton.isColorSelected = NO;
    sender.isColorSelected = YES;
    self.selectedColorButton = sender;
    
    if (self.colorModeSelector.selectedSegmentIndex == 0) {
        self.drawingBoard.strokeColor = sender.backgroundColor;
    } else {
        self.drawingBoard.fillColor = sender.backgroundColor;
    }
}

- (void)colorModeChanged:(UISegmentedControl *)sender {
    UIColor *targetColor = (sender.selectedSegmentIndex == 0) ? self.drawingBoard.strokeColor : self.drawingBoard.fillColor;
    self.selectedColorButton.isColorSelected = NO;
    self.selectedColorButton = nil;
    for (ColorButton *button in self.colorStack.arrangedSubviews) {
        if ([button.backgroundColor isEqual:targetColor]) {
            button.isColorSelected = YES;
            self.selectedColorButton = button;
            break;
        }
    }
}

- (void)clearFillColorTapped {
    self.drawingBoard.fillColor = nil;
    
    // 如果已有Alert在显示，先关闭它
    if (self.currentAlert && self.currentAlert.presentingViewController) {
        [self.currentAlert dismissViewControllerAnimated:NO completion:nil];
        self.currentAlert = nil;
    }
    
    // 创建新的Alert
    self.currentAlert = [UIAlertController alertControllerWithTitle:nil message:@"Fill color cleared" preferredStyle:UIAlertControllerStyleAlert];
    
    // 检查当前视图控制器是否可以呈现Alert
    if (self.presentedViewController == nil) {
        [self presentViewController:self.currentAlert animated:YES completion:nil];
        
        // 自动关闭Alert
        __weak typeof(self) weakSelf = self;
        dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(1.0 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
            __strong typeof(weakSelf) strongSelf = weakSelf;
            if (strongSelf && strongSelf.currentAlert && strongSelf.currentAlert.presentingViewController) {
                [strongSelf.currentAlert dismissViewControllerAnimated:YES completion:^{
                    strongSelf.currentAlert = nil;
                }];
            }
        });
    }
}

- (void)widthChanged:(UISlider *)sender { self.drawingBoard.lineWidth = sender.value; }
- (void)fontSizeChanged:(UISlider *)sender { self.drawingBoard.fontSize = sender.value; }
- (void)lineStyleChanged:(UISegmentedControl *)sender {
    self.drawingBoard.lineDashPattern = (sender.selectedSegmentIndex == 0) ? nil : @[@10, @5];
}
- (void)zoomSwitchChanged:(UISwitch *)sender {
    self.drawingBoard.zoomEnabled = sender.isOn;
    self.zoomLabel.text = sender.isOn ? @"Disable Zoom" : @"Enable Zoom";
}
- (void)undoTapped { [self.drawingBoard undo]; }
- (void)redoTapped { [self.drawingBoard redo]; }
- (void)clearTapped { [self.drawingBoard clearDrawing]; }
- (void)restoreTapped { 
    [self.drawingBoard restoreAllDrawing];
    
    // 如果已有Alert在显示，先关闭它
    if (self.currentAlert && self.currentAlert.presentingViewController) {
        [self.currentAlert dismissViewControllerAnimated:NO completion:nil];
        self.currentAlert = nil;
    }
    
    // 创建新的Alert
    self.currentAlert = [UIAlertController alertControllerWithTitle:nil message:@"All drawings restored!" preferredStyle:UIAlertControllerStyleAlert];
    
    // 检查当前视图控制器是否可以呈现Alert
    if (self.presentedViewController == nil) {
        [self presentViewController:self.currentAlert animated:YES completion:nil];
        
        // 自动关闭Alert
        __weak typeof(self) weakSelf = self;
        dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(1.0 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
            __strong typeof(weakSelf) strongSelf = weakSelf;
            if (strongSelf && strongSelf.currentAlert && strongSelf.currentAlert.presentingViewController) {
                [strongSelf.currentAlert dismissViewControllerAnimated:YES completion:^{
                    strongSelf.currentAlert = nil;
                }];
            }
        });
    }
}

- (void)saveTapped {
    UIImage *finalImage = [self.drawingBoard captureDrawingWithOriginalSize];
    UIImageWriteToSavedPhotosAlbum(finalImage, self, @selector(image:didFinishSavingWithError:contextInfo:), nil);
}

- (void)selectImageTapped {
    UIImagePickerController *picker = [[UIImagePickerController alloc] init];
    picker.delegate = self;
    picker.sourceType = UIImagePickerControllerSourceTypePhotoLibrary;
    [self presentViewController:picker animated:YES completion:nil];
}

- (void)image:(UIImage *)image didFinishSavingWithError:(NSError *)error contextInfo:(void *)contextInfo {
    // 确保在主线程更新UI
    dispatch_async(dispatch_get_main_queue(), ^{
        NSString *message = error ? [error localizedDescription] : @"Image saved to Photos successfully!";
        UIAlertController *alert = [UIAlertController alertControllerWithTitle:nil message:message preferredStyle:UIAlertControllerStyleAlert];
        [alert addAction:[UIAlertAction actionWithTitle:@"OK" style:UIAlertActionStyleDefault handler:nil]];
        [self presentViewController:alert animated:YES completion:nil];
    });
}

#pragma mark - UIImagePickerControllerDelegate

- (void)imagePickerController:(UIImagePickerController *)picker didFinishPickingMediaWithInfo:(NSDictionary<UIImagePickerControllerInfoKey,id> *)info {
    UIImage *selectedImage = info[UIImagePickerControllerOriginalImage];
    if (selectedImage) {
        [self.drawingBoard setupWithImage:selectedImage];
    }
    [picker dismissViewControllerAnimated:YES completion:nil];
}

- (void)imagePickerControllerDidCancel:(UIImagePickerController *)picker {
    [picker dismissViewControllerAnimated:YES completion:nil];
}

#pragma mark - DrawingBoardViewDelegate

- (void)drawingBoardView:(DrawingBoardView *)boardView didSelectItem:(id)item {
    if (item == nil) {
        // No item selected, do nothing or reset to a default state
        return;
    }

    if ([item isKindOfClass:[DrawingShape class]]) {
        DrawingShape *shape = (DrawingShape *)item;
        
        // Update width slider
        self.widthSlider.value = shape.lineWidth;
        
        // Update stroke color
        [self selectColorButtonForColor:shape.strokeColor inMode:0];
        
        // Update fill color
        if (shape.fillColor) {
            [self selectColorButtonForColor:shape.fillColor inMode:1];
        } else {
            // Handle no fill color if needed
        }
        
        // Update line style
        self.lineStyleSelector.selectedSegmentIndex = (shape.lineDashPattern == nil) ? 0 : 1;
        
    } else if ([item isKindOfClass:[DrawingText class]]) {
        DrawingText *text = (DrawingText *)item;
        
        // Update font size slider
        UIFont *font = text.attributes[NSFontAttributeName];
        self.fontSizeSlider.value = font.pointSize;
        
        // Update text color
        UIColor *textColor = text.attributes[NSForegroundColorAttributeName];
        [self selectColorButtonForColor:textColor inMode:0];
    }
}

- (void)selectColorButtonForColor:(UIColor *)color inMode:(NSInteger)mode {
    // 设置颜色模式
    self.colorModeSelector.selectedSegmentIndex = mode;

    // 清除当前选中状态
    if (self.selectedColorButton) {
        self.selectedColorButton.isColorSelected = NO;
    }
    self.selectedColorButton = nil;
    
    // 查找匹配的颜色按钮
    for (ColorButton *button in self.colorStack.arrangedSubviews) {
        if ([button isKindOfClass:[ColorButton class]]) {
            if (CGColorEqualToColor(button.backgroundColor.CGColor, color.CGColor)) {
                button.isColorSelected = YES;
                self.selectedColorButton = button;
                break;
            }
        }
    }
}

@end
