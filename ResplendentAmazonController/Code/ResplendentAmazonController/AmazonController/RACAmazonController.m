//
//  AmazonController.m
//  Pineapple
//
//  Created by Benjamin Maer on 3/17/13.
//  Copyright (c) 2013 Pineapple. All rights reserved.
//

#import "RACAmazonController.h"

#import "RUConstants.h"
#import "RUDLog.h"





static dispatch_queue_t __imageToDataQueue;





@interface RACAmazonController ()

@property (nonatomic, readonly) NSString* _imageRequestContentType;

@end





@implementation RACAmazonController

+(void)initialize
{
    if (self == [RACAmazonController class])
    {
        __imageToDataQueue = dispatch_queue_create("RUAmazonController.ImageToDataQueue", 0);
    }
}

-(id)init
{
    if (self = [super init])
    {
        _amazonS3Client = [[AmazonS3Client alloc] initWithAccessKey:self.accessKey withSecretKey:self.secretKey];

        //If you want to create the bucket
//        [_amazonS3Client createBucket:[[S3CreateBucketRequest alloc] initWithName:self.bucketName]];
    }

    return self;
}

-(S3PutObjectRequest*)newImagePutRequestWithImageName:(NSString*)imageName
{
    S3PutObjectRequest* request = [[S3PutObjectRequest alloc] initWithKey:imageName inBucket:self.bucketName];
    [request setContentType:self._imageRequestContentType];
    [request setDelegate:self];
    return request;
}

-(S3PutObjectRequest*)uploadImage:(UIImage*)image imageName:(NSString*)imageName
{
    S3PutObjectRequest* request = [self newImagePutRequestWithImageName:imageName];

    [self sendRequest:request withCurrentSettingsAppliedToImage:image];

    return request;
}

-(void)sendRequest:(S3PutObjectRequest *)request withCurrentSettingsAppliedToImage:(UIImage*)image
{
    dispatch_async(__imageToDataQueue, ^{
        [request setData:UIImagePNGRepresentation(image)];
        [self sendRequest:request];
    });
}

-(S3PutObjectRequest*)uploadImageWithData:(NSData*)imageData imageName:(NSString*)imageName
{
    S3PutObjectRequest* request = [self newImagePutRequestWithImageName:imageName];
    [request setData:imageData];
    [self sendRequest:request];

    return request;
}

-(void)sendRequest:(S3PutObjectRequest*)request
{
    dispatch_async(dispatch_get_main_queue(), ^{
        [_amazonS3Client putObject:request];
    });
}

-(NSURL*)imageURLForImageName:(NSString*)imageName
{
    S3GetPreSignedURLRequest *gpsur = [S3GetPreSignedURLRequest new];
    gpsur.key     = imageName;
    gpsur.bucket  = self.bucketName;
    gpsur.expires = [NSDate dateWithTimeIntervalSinceNow:(NSTimeInterval) 3600];  // Added an hour's worth of seconds to the current time.

    S3ResponseHeaderOverrides *override = [S3ResponseHeaderOverrides new];
    [override setContentType:self._imageRequestContentType];
    gpsur.responseHeaderOverrides = override;

    NSURL* url = [_amazonS3Client getPreSignedURL:gpsur];
    return url;
}

#pragma mark - Getter method
-(NSString *)accessKey
{
    RU_METHOD_OVERLOADED_IMPLEMENTATION_NEEDED_EXCEPTION;
}

-(NSString *)secretKey
{
    RU_METHOD_OVERLOADED_IMPLEMENTATION_NEEDED_EXCEPTION;
}

-(NSString *)bucketName
{
    RU_METHOD_OVERLOADED_IMPLEMENTATION_NEEDED_EXCEPTION;
}

#pragma mark - AmazonServiceRequestDelegate methods
-(void)request:(AmazonServiceRequest *)request didCompleteWithResponse:(AmazonServiceResponse *)response
{
    RUDLog(@"finished uploading image with response %@ body %@",response,response.body);
    [self.delegate amazonController:self didFinishWithResponse:response];
}

-(void)request:(AmazonServiceRequest *)request didFailWithError:(NSError *)error
{
    [self.delegate amazonController:self didFailWithError:error];
}

#pragma mark - imageRequestContentType
-(NSString *)_imageRequestContentType
{
    NSString* imageRequestContentType = self.imageRequestContentType;
    if (imageRequestContentType.length)
    {
        return imageRequestContentType;
    }
    else
    {
        return @"image/png";
    }
}

@end
