//
//  GraphicFrag.m
//  SVGRendererTouch
//
//  Created by Aaron Boxer on 11-04-19.
//  Copyright 2011 __MyCompanyName__. All rights reserved.
//

#import "GraphicFrag.h"


@implementation GraphicFrag

@synthesize style, transform;

-(id)copyWithZone:(NSZone *)zone
{ 
    GraphicFrag* another = [GraphicFrag new];
    another.style = [style copyWithZone:nil];
    another.transform = transform;
    
    return another;
}


-(void) draw:(CGContextRef)context
{
    
}

-(id) initWithStyle:(SVGStyle*)astyle transform:(CGAffineTransform)atransform
{
    if ( (self = [super init]) )
    {
        self.style = [astyle copyWithZone:nil];
        self.transform = atransform;
        
    }
    return self;
    
}

- (void)dealloc
{
    [style release];
    [super dealloc];
    
}




@end