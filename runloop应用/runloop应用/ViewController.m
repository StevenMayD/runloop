//
//  ViewController.m
//  runloop应用
//
//  Created by 董帅文 on 2023/7/19.
//

#import "ViewController.h"

@interface ViewController ()
@property (nonatomic, strong) NSThread* myThread; // 线程对象
@end

@implementation ViewController

- (void)viewDidLoad {
    [super viewDidLoad];
    
    // 一、runloop体验：runloop需要有item才能起作用
//    [self feelRunloop];
    
    // 二、深入理解PerformSelector：当perform selector在后台线程中执行的时候，这个线程必须有一个开启的runLoop
    [self understandingPerformSelector];
    
    // 三、一直"活着"的后台线程(创建常驻线程)：需要给runloop添加item，runloop所属的线程才能保活
//    [self alwaysLiveBackGoundThread];
}

#pragma mark - feelRunloop
- (void)feelRunloop {
    // 主线程中，这个循环 不会被一直执行，即runloop起作用了
//    while (1) {
//        NSLog(@"while begin-111");
//        NSRunLoop *runLoop = [NSRunLoop currentRunLoop];
//        [runLoop runMode:NSDefaultRunLoopMode beforeDate:[NSDate distantFuture]];
//        NSLog(@"while end-111");
//    }
    
    
    /* 子线程中，这个循环 会被一直执行，即runloop没有起作用了
     我们看到虽然有Mode，但是我们没有给它soures,observer,timer，其实Mode中的这些source,observer,timer，统称为这个Mode的item，
     如果一个Mode中一个item都没有，则这个RunLoop会直接退出，不进入循环(其实线程之所以可以一直存在就是由于RunLoop将其带入了这个循环中)
     */
//    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
//        while (1) {
//            NSLog(@"while begin-222");
//            NSRunLoop *subRunLoop = [NSRunLoop currentRunLoop];
//            [subRunLoop runMode:NSDefaultRunLoopMode beforeDate:[NSDate distantFuture]];
//            NSLog(@"while end-222");
//            NSLog(@"%@",subRunLoop);
//            /*
//                 sources0 = (null),
//                 sources1 = (null),
//                 observers = (null),
//                 timers = (null),
//             */
//        }
//    });
    
    /* 下面我们为这个子线程 RunLoop添加个source:
     这样能够实现了和主线程中相同的效果，线程在这个地方暂停了，为什么呢？我们明明让RunLoop在distantFuture之前都一直run的啊？
     相信大家已经猜出出来了。这个时候线程被RunLoop带到‘坑’里去了，这个‘坑’就是一个循环，在循环中这个线程可以在没有任务的时候休眠，在有任务的时候被唤醒；
     当然我们只用一个while(1)也可以让这个线程一直存在，但是这个线程会一直在唤醒状态，及时它没有任务也一直处于运转状态，这对于CPU来说是非常不高效的。
     
     小结:我们的RunLoop要想工作，必须要让它存在一个Item(source,observer或者timer)，主线程之所以能够一直存在，并且随时准备被唤醒就是应为系统为其添加了很多Item
     */
    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
            while (1) {
            NSLog(@"while begin-333");
            NSRunLoop *subRunLoop = [NSRunLoop currentRunLoop];
            NSPort *macPort = [NSPort port];
            [subRunLoop addPort:macPort forMode:NSDefaultRunLoopMode];
            NSLog(@"subRunLoop1 - %@",subRunLoop);
            /*
             sources0 = <CFBasicHash 0x600002e14120 [0x7ff865b1f1e0]>{type = mutable set, count = 0
             sources1 = <CFBasicHash 0x600002e15110 [0x7ff865b1f1e0]>{type = mutable set, count = 1
             observers = (null),
             timers = (null),
             */
            [subRunLoop runMode:NSDefaultRunLoopMode beforeDate:[NSDate distantFuture]];
            NSLog(@"while end-333");
            NSLog(@"subRunLoop2 - %@",subRunLoop);
        }
    });
}

#pragma mark - understandingPerformSelector

- (void)understandingPerformSelector {
//    [self tryPerformSelectorOnMianThread]; // 主线程中执行 PerformSelector：会执行
//    [self tryPerformSelectorOnBackGroundThreadNoRunloop]; // 子线程中执行 PerformSelector：不会执行
    [self tryPerformSelectorOnBackGroundThreadWithRunloop]; // 子线程中执行 PerformSelector：会执行
}

- (void)tryPerformSelectorOnMianThread{
    [self performSelector:@selector(mainThreadMethod) withObject:nil];
}
- (void)mainThreadMethod{
    NSLog(@"execute %s",__func__); // print: execute -[ViewController mainThreadMethod]
    NSLog(@"%u",[NSThread isMainThread]); // print: 1
    NSLog(@"%@", [NSRunLoop currentRunLoop]); // 有item
    /* 执行了
     这是因为，在调用performSelector:onThread: withObject: waitUntilDone的时候
     系统会给我们创建一个Timer的source，加到对应的RunLoop上去
     且主线程的RunLoop是一直存在的，所以我们在主线程中执行的时候，无需再添加RunLoop
     */
}

- (void)tryPerformSelectorOnBackGroundThreadNoRunloop{
    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
        [self performSelector:@selector(backGroundThread) onThread:[NSThread currentThread] withObject:nil waitUntilDone:NO];
        /* 不会执行 backGroundThread
         因为虽然performSelector方法会自动创建item，但子线程中Runloop默认没有启动
         */
    });
}

- (void)tryPerformSelectorOnBackGroundThreadWithRunloop{
    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
        [self performSelector:@selector(backGroundThread) onThread:[NSThread currentThread] withObject:nil waitUntilDone:NO];
        NSRunLoop *runLoop = [NSRunLoop currentRunLoop];
        [runLoop run];
        /* 会执行 backGroundThread
         因为performSelector方法会自动创建item，这里又将子线程中的runloop手动启动了
         */
    });
}

- (void)backGroundThread{
    NSLog(@"%u",[NSThread isMainThread]);
    NSLog(@"execute %s",__FUNCTION__);
}

#pragma mark - alwaysLiveBackGoundThread
- (void)alwaysLiveBackGoundThread{
    NSThread *thread = [[NSThread alloc]initWithTarget:self selector:@selector(myThreadRun) object:@"etund"];
    self.myThread = thread;
    [self.myThread start]; // 线程启动
}

- (void)myThreadRun{
    /* 给当前线程的runloop添加item任务(使得线程成为保活线程)：currentRunLoop就是当前线程self.myThread的runloop
     就是监听了这个端口如果有事件到来，线程就被唤醒，如果没有事件到来，线程就会休眠。
     其实每个处理器都有很多的中断口，我们每个事件都是通过这些中断口传递给处理器，然后处理器再传递给操作系统。
     添加macPort的意思就是告诉操作系统，如果这个口上有中断产生，就唤醒这个线程，处理该事件。
     */
    [[NSRunLoop currentRunLoop] addPort:[[NSPort alloc] init] forMode:NSDefaultRunLoopMode];
    [[NSRunLoop currentRunLoop] run];
    
    /*
     11、这里不会执行：由于给线程self.myThread的runloop添加了item任务，线程保活了，会持续等待任务的到来； 22、执行了 33、执行了
     如果没有给当前线程的runloop添加item，那么 11、将执行，22、执行，33、不会执行
     */
    NSLog(@"11、my thread run");
}

// 触碰屏幕 触发在self.myThread调用doBackGroundThreadWork方法
- (void)touchesBegan:(NSSet<UITouch *> *)touches withEvent:(UIEvent *)event{
    NSLog(@"22、%@",self.myThread); // 这里执行了
    // self.myThread线程存在，并且是保活线程
    [self performSelector:@selector(doBackGroundThreadWork) onThread:self.myThread withObject:nil waitUntilDone:NO];
}
- (void)doBackGroundThreadWork{
    NSLog(@"33、do some work %s",__FUNCTION__); // 这里执行了
}

@end
