//
//  SVGWorldParser.m
//  StuntBike X
//
//  Created by Joacim Magnusson on 2010-09-20.
//  Copyright 2010 Joacim Magnusson. All rights reserved.
//

#import "SVGQuartzRenderer.h"
#import "NSData+Base64.h"

@interface SVGQuartzRenderer (hidden)

	- (void)setStyleContext:(NSString *)style;
	- (void)drawPath:(NSBezierPath *)path withStyle:(NSString *)style;
	- (void)applyTransformations:(NSString *)transformations;
	- (NSDictionary *)getCompleteDefinitionFromID:(NSString *)identifier;

@end

@implementation SVGQuartzRenderer

NSXMLParser* xmlParser;
NSAffineTransform *transform;
NSAffineTransform *identity;
CGSize documentSize;
NSView *view;
NSMutableDictionary *defDict;

NSMutableDictionary *curPat;
NSMutableDictionary *curGradient;
NSMutableDictionary *curFilter;
NSMutableDictionary *curLayer;

BOOL inDefSection = NO;

// Variables for storing style data
// -------------------------------------------------------------------------
BOOL doFill;
NSColor *fillColor;
float fillOpacity;
BOOL doStroke = NO;
unsigned int strokeColor = 0;
float strokeWidth = 1.0;
float strokeOpacity;
NSLineJoinStyle lineJoinStyle;
NSLineCapStyle lineCapStyle;
float miterLimit;
NSImage *fillImage;
NSString *fillType;
NSGradient *fillGradient;
// -------------------------------------------------------------------------

- (id)init {
    self = [super init];
    if (self) {
        xmlParser = [NSXMLParser alloc];
		transform = [[NSAffineTransform transform] retain];
		identity = [[NSAffineTransform transform] retain];

		defDict = [[NSMutableDictionary alloc] init];
    }
    return self;
}

- (void)resetStyleContext
{
	doFill = YES;
	fillColor = nil;
	fillOpacity = 1.0;
	doStroke = NO;
	strokeColor = 0;
	strokeWidth = 1.0;
	strokeOpacity = 1.0;
	lineJoinStyle = NSMiterLineJoinStyle;
	lineCapStyle = NSButtLineCapStyle;
	miterLimit = 4;
	fillImage = nil;
	fillType = @"solid";
}

- (void)imageFromSVGFile:(NSString *)file view:(NSView *)aView
{
	NSData *xml = [[NSData dataWithContentsOfFile:file] autorelease];
	xmlParser = [xmlParser initWithData:xml];
	
	view = aView;
	
	[xmlParser setDelegate:self];
	[xmlParser setShouldResolveExternalEntities:NO];
	[xmlParser parse];
}


// Element began
// -----------------------------------------------------------------------------
- (void)parser:(NSXMLParser *)parser
didStartElement:(NSString *)elementName 
  namespaceURI:(NSString *)namespaceURI
 qualifiedName:(NSString *)qualifiedName
	attributes:(NSDictionary *)attrDict
{
	NSAutoreleasePool *pool =  [[NSAutoreleasePool alloc] init];
	
	// Path used for rendering
	NSBezierPath * path = [NSBezierPath bezierPath];
	
	// Top level SVG node
	// -------------------------------------------------------------------------
	if([elementName isEqualToString:@"svg"]) {
		documentSize = CGSizeMake([[attrDict valueForKey:@"width"] floatValue],
							   [[attrDict valueForKey:@"height"] floatValue]);
		
		[view setFrame:NSMakeRect(0, 0, documentSize.width, documentSize.height)];
		
		doStroke = NO;
	}
	
	// Definitions
	// -------------------------------------------------------------------------
	if([elementName isEqualToString:@"defs"]) {
		defDict = [[NSMutableDictionary alloc] init];
		inDefSection = YES;
	}
	
		if([elementName isEqualToString:@"pattern"]) {
			curPat = [[NSMutableDictionary alloc] init];
			
			NSEnumerator *enumerator = [attrDict keyEnumerator];
			id key;
			while ((key = [enumerator nextObject])) {
				NSDictionary *obj = [attrDict objectForKey:key];
				[curPat setObject:obj forKey:key];
			}
			[curPat setObject:[[NSMutableArray alloc] init] forKey:@"images"];
			[curPat setObject:@"pattern" forKey:@"type"];
		}
			if([elementName isEqualToString:@"image"]) {
				NSMutableDictionary *imageDict = [[NSMutableDictionary alloc] init];
				NSEnumerator *enumerator = [attrDict keyEnumerator];
				id key;
				while ((key = [enumerator nextObject])) {
					NSDictionary *obj = [attrDict objectForKey:key];
					[imageDict setObject:obj forKey:key];
				}
				[[curPat objectForKey:@"images"] addObject:imageDict];
			}
		
		if([elementName isEqualToString:@"linearGradient"]) {
			curGradient = [[NSMutableDictionary alloc] init];
			NSEnumerator *enumerator = [attrDict keyEnumerator];
			id key;
			while ((key = [enumerator nextObject])) {
				NSDictionary *obj = [attrDict objectForKey:key];
				[curGradient setObject:obj forKey:key];
			}
			[curGradient setObject:@"linearGradient" forKey:@"type"];
			[curGradient setObject:[[NSMutableArray alloc] init] forKey:@"stops"];
		}
			if([elementName isEqualToString:@"stop"]) {
				NSMutableDictionary *stopDict = [[NSMutableDictionary alloc] init];
				NSEnumerator *enumerator = [attrDict keyEnumerator];
				id key;
				while ((key = [enumerator nextObject])) {
					NSDictionary *obj = [attrDict objectForKey:key];
					[stopDict setObject:obj forKey:key];
				}
				[[curGradient objectForKey:@"stops"] addObject:stopDict];
			}
		
		if([elementName isEqualToString:@"radialGradient"]) {
			curGradient = [[NSMutableDictionary alloc] init];
			NSEnumerator *enumerator = [attrDict keyEnumerator];
			id key;
			while ((key = [enumerator nextObject])) {
				NSDictionary *obj = [attrDict objectForKey:key];
				[curGradient setObject:obj forKey:key];
			}
			[curGradient setObject:@"radialGradient" forKey:@"type"];
		}
	
		if([elementName isEqualToString:@"filter"]) {
			curFilter = [[NSMutableDictionary alloc] init];
		}
			if([elementName isEqualToString:@"feGaussianBlur"]) {
				
			}
	
	// Group node
	// -------------------------------------------------------------------------
	if([elementName isEqualToString:@"g"]) {
		
		curLayer = [[NSMutableDictionary alloc] init];
		NSEnumerator *enumerator = [attrDict keyEnumerator];
		id key;
		while ((key = [enumerator nextObject])) {
			NSDictionary *obj = [attrDict objectForKey:key];
			[curLayer setObject:obj forKey:key];
		}
		
		
		// Reset styles for each layer
		[self resetStyleContext];
		
		if([attrDict valueForKey:@"style"])
			[self setStyleContext:[attrDict valueForKey:@"style"]];
		
		if([attrDict valueForKey:@"transform"])
			[self applyTransformations:[attrDict valueForKey:@"transform"]];
	}
	
	
	// Path node
	// -------------------------------------------------------------------------
	if([elementName isEqualToString:@"path"]) {
		
		// For now, we'll ignore paths in definitions
		if(inDefSection)
			return;
		
		if([attrDict valueForKey:@"transform"])
			[self applyTransformations:[attrDict valueForKey:@"transform"]];
		
		// Create a scanner for parsing path data
		NSScanner *scanner = [NSScanner scannerWithString:[attrDict valueForKey:@"d"]];
		[scanner setCaseSensitive:YES];
		[scanner setCharactersToBeSkipped:[NSCharacterSet newlineCharacterSet]];
		
		CGPoint curPoint = CGPointMake(0,0);
		CGPoint curCtrlPoint1 = CGPointMake(-1,-1);
		CGPoint curCtrlPoint2 = CGPointMake(-1,-1);
		CGPoint firstPoint = CGPointMake(-1,-1);
		NSString *curCmdType = nil;
		
		NSCharacterSet *cmdCharSet = [NSCharacterSet characterSetWithCharactersInString:@"mMlLhHvVcCsSqQtTaAzZ"];
		NSCharacterSet *separatorSet = [NSCharacterSet characterSetWithCharactersInString:@" ,"];
		NSString *currentCommand = nil;
		NSString *currentParams = nil;
		while ([scanner scanCharactersFromSet:cmdCharSet intoString:&currentCommand]) {
			[scanner scanUpToCharactersFromSet:cmdCharSet intoString:&currentParams];
			
			NSArray *params = [currentParams componentsSeparatedByCharactersInSet:separatorSet];
			
			int paramCount = [params count];
			
			for (int prm_i = 0; prm_i < paramCount;) {
				if(![[params objectAtIndex:prm_i] isEqualToString:@""]) {
					
					BOOL firstVertex = (firstPoint.x == -1 && firstPoint.y == -1);
					
					// Move to absolute coord
					//-----------------------------------------
					if([currentCommand isEqualToString:@"M"]) {
						curCmdType = @"line";
						curPoint.x = [[params objectAtIndex:prm_i++] floatValue];
						curPoint.y = [[params objectAtIndex:prm_i++] floatValue];
					}
					
					// Move to relative coord
					//-----------------------------------------
					if([currentCommand isEqualToString:@"m"]) {
						curCmdType = @"line";
						curPoint.x += [[params objectAtIndex:prm_i++] floatValue];
						
						if(firstVertex) {
							curPoint.y = [[params objectAtIndex:prm_i++] floatValue];
						} else {
							curPoint.y += [[params objectAtIndex:prm_i++] floatValue];
						}
					}
					
					// Line to absolute coord
					//-----------------------------------------
					if([currentCommand isEqualToString:@"L"]) {
						curCmdType = @"line";
						curPoint.x = [[params objectAtIndex:prm_i++] floatValue];
						curPoint.y = [[params objectAtIndex:prm_i++] floatValue];
					}
					
					// Line to relative coord
					//-----------------------------------------
					if([currentCommand isEqualToString:@"l"]) {
						curCmdType = @"line";
						curPoint.x += [[params objectAtIndex:prm_i++] floatValue];
						if(firstVertex) {
							curPoint.y = [[params objectAtIndex:prm_i++] floatValue];
						} else {
							curPoint.y += [[params objectAtIndex:prm_i++] floatValue];
						}
					}
					
					// Horizontal line to absolute coord
					//-----------------------------------------
					if([currentCommand isEqualToString:@"H"]) {
						curCmdType = @"line";
						curPoint.x = [[params objectAtIndex:prm_i++] floatValue];
					}
					
					// Horizontal line to relative coord
					//-----------------------------------------
					if([currentCommand isEqualToString:@"h"]) {
						curCmdType = @"line";
						curPoint.x += [[params objectAtIndex:prm_i++] floatValue];
					}
					
					// Vertical line to absolute coord
					//-----------------------------------------
					if([currentCommand isEqualToString:@"V"]) {
						curCmdType = @"line";
						curPoint.y = [[params objectAtIndex:prm_i++] floatValue];
					}
					
					// Vertical line to relative coord
					//-----------------------------------------
					if([currentCommand isEqualToString:@"v"]) {
						curCmdType = @"line";
						curPoint.y += [[params objectAtIndex:prm_i++] floatValue];
					}
					
					// Curve to absolute coord
					//-----------------------------------------
					if([currentCommand isEqualToString:@"C"]) {
						curCmdType = @"curve";
						
						curCtrlPoint1.x = [[params objectAtIndex:prm_i++] floatValue];
						curCtrlPoint1.y = [[params objectAtIndex:prm_i++] floatValue];
						
						curCtrlPoint2.x = [[params objectAtIndex:prm_i++] floatValue];
						curCtrlPoint2.y = [[params objectAtIndex:prm_i++] floatValue];
						
						curPoint.x = [[params objectAtIndex:prm_i++] floatValue];
						curPoint.y = [[params objectAtIndex:prm_i++] floatValue];
					}
					
					// Curve to relative coord
					//-----------------------------------------
					if([currentCommand isEqualToString:@"c"]) {
						curCmdType = @"curve";
						
						curCtrlPoint1.x = curPoint.x + [[params objectAtIndex:prm_i++] floatValue];
						curCtrlPoint1.y = curPoint.y + [[params objectAtIndex:prm_i++] floatValue];
						
						curCtrlPoint2.x = curPoint.x + [[params objectAtIndex:prm_i++] floatValue];
						curCtrlPoint2.y = curPoint.y + [[params objectAtIndex:prm_i++] floatValue];
						
						curPoint.x += [[params objectAtIndex:prm_i++] floatValue];
						curPoint.y += [[params objectAtIndex:prm_i++] floatValue];
					}
					
					// Shorthand curve to absolute coord
					//-----------------------------------------
					if([currentCommand isEqualToString:@"S"]) {
						curCmdType = @"curve";
						
						if(curCtrlPoint2.x != -1 && curCtrlPoint2.y != -1) {
							curCtrlPoint1.x = curCtrlPoint2.x;
							curCtrlPoint1.y = curCtrlPoint2.y;
						} else {
							curCtrlPoint1.x = curPoint.x;
							curCtrlPoint1.y = curPoint.y;
						}
						
						curCtrlPoint2.x = [[params objectAtIndex:prm_i++] floatValue];
						curCtrlPoint2.y = [[params objectAtIndex:prm_i++] floatValue];
						
						curPoint.x = [[params objectAtIndex:prm_i++] floatValue];
						curPoint.y = [[params objectAtIndex:prm_i++] floatValue];
					}
					
					// Shorthand curve to relative coord
					//-----------------------------------------
					if([currentCommand isEqualToString:@"s"]) {
						curCmdType = @"curve";
						
						if(curCtrlPoint2.x != -1 && curCtrlPoint2.y != -1) {
							curCtrlPoint1.x = curPoint.x + curCtrlPoint2.x;
							curCtrlPoint1.y = curPoint.y + curCtrlPoint2.x;
						} else {
							curCtrlPoint1.x = curPoint.x;
							curCtrlPoint1.y = curPoint.y;
						}
						
						curCtrlPoint2.x = curPoint.x + [[params objectAtIndex:prm_i++] floatValue];
						curCtrlPoint2.y = curPoint.y + [[params objectAtIndex:prm_i++] floatValue];
						
						curPoint.x += [[params objectAtIndex:prm_i++] floatValue];
						curPoint.y += [[params objectAtIndex:prm_i++] floatValue];
					}
					
					
					// Not yet implemented commands
					if([currentCommand isEqualToString:@"q"] || [currentCommand isEqualToString:@"Q"]) {
						prm_i++;
					}
					if([currentCommand isEqualToString:@"t"] || [currentCommand isEqualToString:@"T"]) {
						prm_i++;
					}
					if([currentCommand isEqualToString:@"a"] || [currentCommand isEqualToString:@"A"]) {
						prm_i++;
					}
					
					if(firstVertex) {
						firstPoint = curPoint;
						[path moveToPoint: firstPoint];
					}
					
					// Close path
					if([currentCommand isEqualToString:@"z"] || [currentCommand isEqualToString:@"Z"]) {
						curCmdType = @"line";
						curPoint = firstPoint;
						firstVertex = YES;
						prm_i++;
					}
					
					if(curCmdType) {
						if([curCmdType isEqualToString:@"line"])
							[path lineToPoint: curPoint];
						
						if([curCmdType isEqualToString:@"curve"])
							[path curveToPoint:curPoint controlPoint1:curCtrlPoint1 controlPoint2:curCtrlPoint2];
					}
				} else {
					prm_i++;
				}

			}
			
			
			
			
			currentParams = nil;
		}
		
		[self drawPath:path withStyle:[attrDict valueForKey:@"style"]];
	}
	
	
	// Rect node
	// -------------------------------------------------------------------------
	if([elementName isEqualToString:@"rect"]) {
		float xPos = [[attrDict valueForKey:@"x"] floatValue];
		float yPos = [[attrDict valueForKey:@"y"] floatValue];
		float width = [[attrDict valueForKey:@"width"] floatValue];
		float height = [[attrDict valueForKey:@"height"] floatValue];
		float ry = [attrDict valueForKey:@"ry"]?[[attrDict valueForKey:@"ry"] floatValue]:-1.0;
		float rx = [attrDict valueForKey:@"rx"]?[[attrDict valueForKey:@"rx"] floatValue]:-1.0;
		
		if (ry==-1.0) ry = rx;
		if (rx==-1.0) rx = ry;
		
		[path appendBezierPathWithRoundedRect:CGRectMake(xPos,yPos,width,height)
									  xRadius:rx
									  yRadius:ry];
		
		[self drawPath:path withStyle:[attrDict valueForKey:@"style"]];
	}
	
	[pool release];
}


// Element ended
// -----------------------------------------------------------------------------
- (void)parser:(NSXMLParser *)parser
 didEndElement:(NSString *)elementName
  namespaceURI:(NSString *)namespaceURI
 qualifiedName:(NSString *)qName
{
	if([elementName isEqualToString:@"svg"]) {
		[fillImage release];
		[defDict release];
	}
	
	if([elementName isEqualToString:@"g"]) {
		// Set the coordinates back the way they were
		//if(cur)
		//[transform invert];
		//[transform concat];
	}
	
	if([elementName isEqualToString:@"defs"]) {
		inDefSection = NO;
	}

	if([elementName isEqualToString:@"path"]) {
		[fillImage release];
		fillImage = nil;
	}
	
	if([elementName isEqualToString:@"pattern"]) {
		if([curPat objectForKey:@"id"])
		[defDict setObject:curPat forKey:[curPat objectForKey:@"id"]];
	}
	
	if([elementName isEqualToString:@"linearGradient"]) {
		if([curGradient objectForKey:@"id"])
		[defDict setObject:curGradient forKey:[curGradient objectForKey:@"id"]];
	}
	
	if([elementName isEqualToString:@"radialGradient"]) {
		if([curGradient objectForKey:@"id"])
		[defDict setObject:curGradient forKey:[curGradient objectForKey:@"id"]];
	}
}


// Draw a path based on style information
// -----------------------------------------------------------------------------
- (void)drawPath:(NSBezierPath *)path withStyle:(NSString *)style
{		
	if(style)
		[self setStyleContext:style];
	
	// Do the drawing
	// -------------------------------------------------------------------------
	if(doFill) {
		if ([fillType isEqualToString:@"solid"] || [fillType isEqualToString:@"pattern"]) {
			[fillColor set];
			[path fill];
		} else if([fillType isEqualToString:@"linearGradient"]) {
			[fillGradient drawInBezierPath:path angle:0];
		} else if([fillType isEqualToString:@"radialGradient"]) {
			[fillGradient drawInBezierPath:path relativeCenterPosition:CGPointMake(0, 0)];
		}
	}
	
	
	if(doStroke) {
		CGFloat red   = ((strokeColor & 0xFF0000) >> 16) / 255.0f;
		CGFloat green = ((strokeColor & 0x00FF00) >>  8) / 255.0f;
		CGFloat blue  =  (strokeColor & 0x0000FF) / 255.0f;
		[[NSColor colorWithDeviceRed:red green:green blue:blue alpha:strokeOpacity] set];
		[path setLineWidth:strokeWidth];
		[path setLineCapStyle:lineCapStyle];
		[path setLineJoinStyle:lineJoinStyle];
		[path setMiterLimit:miterLimit];
		[path stroke];
	}
}

- (void)setStyleContext:(NSString *)style
{
	NSAutoreleasePool *pool =  [[NSAutoreleasePool alloc] init];
	
	// Scan the style string and parse relevant data
	// -------------------------------------------------------------------------
	NSScanner *cssScanner = [NSScanner scannerWithString:style];
	[cssScanner setCaseSensitive:YES];
	[cssScanner setCharactersToBeSkipped:[NSCharacterSet newlineCharacterSet]];
	
	NSString *currentAttribute;
	while ([cssScanner scanUpToString:@";" intoString:&currentAttribute]) {
		NSArray *attrAr = [currentAttribute componentsSeparatedByString:@":"];
		
		NSString *attrName = [attrAr objectAtIndex:0];
		NSString *attrValue = [attrAr objectAtIndex:1];
		
		// --------------------- FILL
		if([attrName isEqualToString:@"fill"]) {
			if(![attrValue isEqualToString:@"none"] && [attrValue rangeOfString:@"url"].location == NSNotFound) {
				
				doFill = YES;
				fillType = @"solid";
				NSScanner *hexScanner = [NSScanner scannerWithString:
										 [attrValue stringByReplacingOccurrencesOfString:@"#" withString:@"0x"]];
				[hexScanner setCharactersToBeSkipped:[NSCharacterSet symbolCharacterSet]]; 
				unsigned int color;
				[hexScanner scanHexInt:&color];
				CGFloat red   = ((color & 0xFF0000) >> 16) / 255.0f;
				CGFloat green = ((color & 0x00FF00) >>  8) / 255.0f;
				CGFloat blue  =  (color & 0x0000FF) / 255.0f;
				fillColor = [[NSColor colorWithDeviceRed:red green:green blue:blue alpha:fillOpacity] retain];
				
			} else if([attrValue rangeOfString:@"url"].location != NSNotFound) {
				
				doFill = YES;
				NSScanner *scanner = [NSScanner scannerWithString:attrValue];
				[scanner setCaseSensitive:YES];
				[scanner setCharactersToBeSkipped:[NSCharacterSet newlineCharacterSet]];
				
				NSString *url;
				[scanner scanString:@"url(" intoString:nil];
				[scanner scanUpToString:@")" intoString:&url];
				
				if([url hasPrefix:@"#"]) {
					// Get def by ID
					NSDictionary *def = [self getCompleteDefinitionFromID:url];
					if([def objectForKey:@"images"] && [[def objectForKey:@"images"] count] > 0) {
						
						// Load bitmap pattern
						fillType = [def objectForKey:@"type"];
						NSString *imgString = [[[def objectForKey:@"images"] objectAtIndex:0] objectForKey:@"xlink:href"];
						NSArray *mimeAndData = [imgString componentsSeparatedByString:@","];
						NSData *imgData = [[NSData dataWithBase64EncodedString:[mimeAndData objectAtIndex:1]] retain];
						NSBitmapImageRep *fillImageRep = [NSBitmapImageRep imageRepWithData:imgData];
						fillImage = [[NSImage alloc] init];
						[fillImage addRepresentation:fillImageRep];
						fillColor = [[NSColor colorWithPatternImage:fillImage] retain];
						
					} else if([def objectForKey:@"stops"] && [[def objectForKey:@"stops"] count] > 0) {
						// Load gradient
						fillType = [def objectForKey:@"type"];
						
						NSArray *stops = [def objectForKey:@"stops"];
						
						NSMutableArray *colors = [[NSMutableArray alloc] init];
						CGFloat locations[[stops count]];
						
						for(int i=0;i<[stops count];i++) {
							unsigned int stopColorRGB = 0;
							CGFloat stopColorAlpha = 1;
							
							NSString *style = [[stops objectAtIndex:i] objectForKey:@"style"];
							NSArray *styles = [style componentsSeparatedByString:@";"];
							for(int si=0;si<[styles count];si++) {
								NSArray *valuePair = [[styles objectAtIndex:si] componentsSeparatedByString:@":"];
								if([valuePair count]==2) {
									if([[valuePair objectAtIndex:0] isEqualToString:@"stop-color"]) {
										// Handle color
										NSScanner *hexScanner = [NSScanner scannerWithString:
																 [[valuePair objectAtIndex:1] stringByReplacingOccurrencesOfString:@"#" withString:@"0x"]];
										[hexScanner scanHexInt:&stopColorRGB];
									}
									if([[valuePair objectAtIndex:0] isEqualToString:@"stop-opacity"]) {
										stopColorAlpha = [[valuePair objectAtIndex:1] floatValue];
									}
								}
							}
							
							CGFloat red   = ((stopColorRGB & 0xFF0000) >> 16) / 255.0f;
							CGFloat green = ((stopColorRGB & 0x00FF00) >>  8) / 255.0f;
							CGFloat blue  =  (stopColorRGB & 0x0000FF) / 255.0f;
							NSColor *stopColorRGBA = [NSColor colorWithDeviceRed:red green:green blue:blue alpha:stopColorAlpha];
							
							[colors addObject:stopColorRGBA];
							locations[i] = [[[stops objectAtIndex:i] objectForKey:@"offset"] floatValue];
						}
						
						fillGradient = [[[NSGradient alloc] initWithColors:colors 
															  atLocations:locations 
															   colorSpace:[NSColorSpace deviceRGBColorSpace]] retain];
					}
				}
			} else {
				doFill = NO;
			}

		}
		
		// --------------------- FILL-OPACITY
		if([attrName isEqualToString:@"fill-opacity"]) {
			NSScanner *floatScanner = [NSScanner scannerWithString:attrValue];
			[floatScanner scanFloat:&fillOpacity];
		}
		
		// --------------------- STROKE
		if([attrName isEqualToString:@"stroke"]) {
			if(![attrValue isEqualToString:@"none"]) {
				doStroke = YES;
				NSScanner *hexScanner = [NSScanner scannerWithString:
										 [attrValue stringByReplacingOccurrencesOfString:@"#" withString:@"0x"]];
				[hexScanner setCharactersToBeSkipped:[NSCharacterSet symbolCharacterSet]]; 
				[hexScanner scanHexInt:&strokeColor];
				strokeWidth = 1;
			} else {
				doStroke = NO;
			}

		}
		
		// --------------------- STROKE-OPACITY
		if([attrName isEqualToString:@"stroke-opacity"]) {
			NSScanner *floatScanner = [NSScanner scannerWithString:attrValue];
			[floatScanner scanFloat:&strokeOpacity];
		}
		
		// --------------------- STROKE-WIDTH
		if([attrName isEqualToString:@"stroke-width"]) {
			NSScanner *floatScanner = [NSScanner scannerWithString:
									   [attrValue stringByReplacingOccurrencesOfString:@"px" withString:@""]];
			[floatScanner scanFloat:&strokeWidth];
		}
		
		// --------------------- STROKE-LINECAP
		if([attrName isEqualToString:@"stroke-linecap"]) {
			NSScanner *stringScanner = [NSScanner scannerWithString:attrValue];
			NSString *lineCapValue;
			[stringScanner scanUpToString:@";" intoString:&lineCapValue];
			
			if([lineCapValue isEqualToString:@"butt"])
				lineCapStyle = NSButtLineCapStyle;
			
			if([lineCapValue isEqualToString:@"round"])
				lineCapStyle = NSRoundLineCapStyle;
			
			if([lineCapValue isEqualToString:@"square"])
				lineCapStyle = NSSquareLineCapStyle;
		}
		
		// --------------------- STROKE-LINEJOIN
		if([attrName isEqualToString:@"stroke-linejoin"]) {
			NSScanner *stringScanner = [NSScanner scannerWithString:attrValue];
			NSString *lineCapValue;
			[stringScanner scanUpToString:@";" intoString:&lineCapValue];
			
			if([lineCapValue isEqualToString:@"miter"])
				lineJoinStyle = NSMiterLineJoinStyle;
			
			if([lineCapValue isEqualToString:@"round"])
				lineJoinStyle = NSRoundLineJoinStyle;
			
			if([lineCapValue isEqualToString:@"bevel"])
				lineJoinStyle = NSBevelLineJoinStyle;
		}
		
		// --------------------- STROKE-MITERLIMIT
		if([attrName isEqualToString:@"stroke-miterlimit"]) {
			NSScanner *floatScanner = [NSScanner scannerWithString:attrValue];
			[floatScanner scanFloat:&miterLimit];
		}
		
		[cssScanner scanString:@";" intoString:nil];
	}
	[pool release];
}

- (void)applyTransformations:(NSString *)transformations
{
	// Reset transformation matrix
	[transform initWithTransform:identity];
	
	NSScanner *scanner = [NSScanner scannerWithString:transformations];
	[scanner setCaseSensitive:YES];
	[scanner setCharactersToBeSkipped:[NSCharacterSet newlineCharacterSet]];
	
	NSString *value;
	
	// Translate
	[scanner scanString:@"translate(" intoString:nil];
	[scanner scanUpToString:@")" intoString:&value];
	
	NSArray *values = [value componentsSeparatedByString:@","];
	
	if([values count] == 2)
		[transform translateXBy:[[values objectAtIndex:0] floatValue] yBy:[[values objectAtIndex:1] floatValue]];
	
	// Rotate
	value = [NSString string];
	[scanner initWithString:transformations];
	[scanner scanString:@"rotate(" intoString:nil];
	[scanner scanUpToString:@")" intoString:&value];
	
	if(value)
		[transform rotateByDegrees:[value floatValue]];
	
	// Matrix
	/*value = [NSString string];
	[scanner initWithString:transformations];
	[scanner scanString:@"matrix(" intoString:nil];
	[scanner scanUpToString:@")" intoString:&value];
	
	values = [value componentsSeparatedByString:@","];
	
	if([values count] == 6) {
		NSAffineTransformStruct matrix;
		matrix.m11 = [[values objectAtIndex:0] floatValue];
		matrix.m12 = [[values objectAtIndex:1] floatValue];
		matrix.m21 = [[values objectAtIndex:2] floatValue];
		matrix.m22 = [[values objectAtIndex:3] floatValue];
		matrix.tX = [[values objectAtIndex:4] floatValue];
		matrix.tY = [[values objectAtIndex:5] floatValue];
		[transform setTransformStruct:matrix];
		NSLog(@"Matrix transform: %@", values);
	}*/
	
	// Apply to graphics context
	[transform concat];
}

- (NSDictionary *)getCompleteDefinitionFromID:(NSString *)identifier
{
	NSString *theId = [identifier stringByReplacingOccurrencesOfString:@"#" withString:@""];
	NSMutableDictionary *def = [defDict objectForKey:theId];
	NSString *xlink = [def objectForKey:@"xlink:href"];
	while(xlink){
		NSMutableDictionary *linkedDef = [defDict objectForKey:
										  [xlink stringByReplacingOccurrencesOfString:@"#" withString:@""]];
		
		if([linkedDef objectForKey:@"images"])
			[def setObject:[linkedDef objectForKey:@"images"] forKey:@"images"];
		
		if([linkedDef objectForKey:@"stops"])
			[def setObject:[linkedDef objectForKey:@"stops"] forKey:@"stops"];
		
		xlink = [linkedDef objectForKey:@"xlink:href"];
	}
	
	return def;
}

- (void)dealloc
{
	[transform release];
	[identity release];
	[defDict release];
	[curPat release];
	[curGradient release];
	[curFilter release];
	[fillImage release];
	[xmlParser release];
	
	[super dealloc];
}

@end
