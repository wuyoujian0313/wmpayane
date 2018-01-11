//
//  alipayManager.m
//  wmpayane
//
//  Created by wuyoujian on 2018/1/11.
//

#import "alipayManager.h"
#import <AlipaySDK/AlipaySDK.h>
#import "APOrderInfo.h"
#import "APRSASigner.h"

@interface alipayManager ()
@property (nonatomic, copy) NSString *appId;
@property (nonatomic, copy) NSString *appSecret;
@property (nonatomic, copy) NSString *rsa2PrivateKey;
@end

@implementation alipayManager

+ (alipayManager*)shareAlipayManager {
    static alipayManager *obj = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        obj = [[self alloc] init];
    });
    return obj;
}

- (void)registerSDK:(NSString*)appId appSecret:(NSString*)appSecret {
    _appId = appId;
    _appSecret = appSecret;
    
    // 获取密钥
}

- (void)pay:(NSString *)payJson {
    NSError * error = nil;
    NSData *jsonData = [payJson dataUsingEncoding:NSUTF8StringEncoding];
    
    /*
     字段:
     goodsDesc :商品描述
     goodsName :商品名称
     orderNo   :订单号
     price     :商品价格
     scheme    :应用程序配置的scheme
     */
    NSDictionary* param = [NSJSONSerialization JSONObjectWithData:jsonData options:NSJSONReadingAllowFragments error:&error];
    /*
     *生成订单信息及签名
     */
    //将商品信息赋予AlixPayOrder的成员变量
    APOrderInfo* order = [APOrderInfo new];
    
    // NOTE: app_id设置
    order.app_id = _appId;
    
    // NOTE: 支付接口名称
    order.method = @"alipay.trade.app.pay";
    
    // NOTE: 参数编码格式
    order.charset = @"utf-8";
    
    // NOTE: 当前时间点
    NSDateFormatter* formatter = [NSDateFormatter new];
    [formatter setDateFormat:@"yyyy-MM-dd HH:mm:ss"];
    order.timestamp = [formatter stringFromDate:[NSDate date]];
    
    // NOTE: 支付版本
    order.version = @"1.0";
    
    // NOTE: sign_type 根据商户设置的私钥来决定
    order.sign_type = _rsa2PrivateKey;
    
    // 商品描述、商品名称、订单号、商品价格
    // goodsDesc、goodsName、orderNo、price
    order.biz_content = [APBizContent new];
    order.biz_content.body = param[@"goodsDesc"];
    order.biz_content.subject = param[@"goodsName"];
    order.biz_content.out_trade_no = param[@"orderNo"];
    order.biz_content.total_amount = param[@"price"];
    order.biz_content.timeout_express = @"30m"; //超时时间设置

    //将商品信息拼接成字符串
    NSString *orderInfo = [order orderInfoEncoded:NO];
    NSString *orderInfoEncoded = [order orderInfoEncoded:YES];
    NSLog(@"orderSpec = %@",orderInfo);

    // NOTE: 获取私钥并将商户信息签名，外部商户的加签过程请务必放在服务端，防止公私钥数据泄露；
    // 需要遵循RSA签名规范，并将签名字符串base64编码和UrlEncode
    NSString *signedString = nil;
    APRSASigner* signer = [[APRSASigner alloc] initWithPrivateKey:_rsa2PrivateKey];
    if ((_rsa2PrivateKey.length > 1)) {
        signedString = [signer signString:orderInfo withRSA2:YES];
    } else {
        signedString = [signer signString:orderInfo withRSA2:NO];
    }

    // NOTE: 如果加签成功，则继续执行支付
    if (signedString != nil) {
        //应用注册scheme
        NSString *appScheme = param[@"scheme"];

        // NOTE: 将签名成功字符串格式化为订单字符串,请严格按照该格式
        NSString *orderString = [NSString stringWithFormat:@"%@&sign=%@",
                                 orderInfoEncoded, signedString];

        // NOTE: 调用支付结果开始支付
        [[AlipaySDK defaultService] payOrder:orderString fromScheme:appScheme callback:^(NSDictionary *resultDic) {
            NSLog(@"reslut = %@",resultDic);
        }];
    }
}

@end