/*
 Copyright (c) 2015, Joel Levin
 All rights reserved.
 
 Redistribution and use in source and binary forms, with or without modification, are permitted provided that the following conditions are met:
 
 Redistributions of source code must retain the above copyright notice, this list of conditions and the following disclaimer.
 Redistributions in binary form must reproduce the above copyright notice, this list of conditions and the following disclaimer in the documentation and/or other materials provided with the distribution.
 Neither the name of JLRoutes nor the names of its contributors may be used to endorse or promote products derived from this software without specific prior written permission.
 THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS "AS IS" AND ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE ARE DISCLAIMED. IN NO EVENT SHALL THE COPYRIGHT HOLDER OR CONTRIBUTORS BE LIABLE FOR ANY DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR CONSEQUENTIAL DAMAGES (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS OR SERVICES; LOSS OF USE, DATA, OR PROFITS; OR BUSINESS INTERRUPTION) HOWEVER CAUSED AND ON ANY THEORY OF LIABILITY, WHETHER IN CONTRACT, STRICT LIABILITY, OR TORT (INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY OUT OF THE USE OF THIS SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.
 */

#import "JLRoute.h"
#import "JLRoutes.h"
#import "NSString+JLRouteAdditions.h"


@interface JLRoute ()

@property (nonatomic, strong, nonnull) NSString *identifier;
@property (nonatomic, strong, nonnull) NSString *path;
@property (nonatomic, strong, nonnull) NSArray <NSString *> *pathComponents;
@property (nonatomic, strong, nonnull) BOOL (^handler)(NSDictionary *__nonnull parameters);
@property (nonatomic) NSUInteger priority;

@end


@implementation JLRoute

- (nonnull instancetype)init
{
    return [self initWithPath:nil priority:JLRouteDefaultPriority handler:nil];
}

- (nonnull instancetype)initWithPath:(nullable NSString *)path priority:(NSUInteger)priority handler:(nullable BOOL (^)(NSDictionary *__nonnull parameters))handlerBlock;
{
    NSParameterAssert(path != nil);
    NSParameterAssert(handlerBlock != nil);
    
    if ((self = [super init]))
    {
        self.path = path;
        self.pathComponents = [[self.path pathComponents] filteredArrayUsingPredicate:[NSPredicate predicateWithFormat:@"NOT SELF like '/'"]];
        self.handler = handlerBlock;
        self.identifier = [[NSUUID UUID] UUIDString];
    }
    return self;
}

- (nonnull NSDictionary *)matchWithURLComponentsIfPossible:(nonnull NSArray<NSString *> *)URLComponents
{
    NSParameterAssert(URLComponents != nil);
    
    NSDictionary *routeParameters = nil;
    
    // do a quick component count check to quickly eliminate incorrect patterns
    BOOL componentCountEqual = self.pathComponents.count == URLComponents.count;
    BOOL routeContainsWildcard = !NSEqualRanges([self.path rangeOfString:@"*"], NSMakeRange(NSNotFound, 0));
    if (componentCountEqual || routeContainsWildcard)
    {
        // now that we've identified a possible match, move component by component to check if it's a match
        NSUInteger componentIndex = 0;
        NSMutableDictionary *variables = [NSMutableDictionary dictionary];
        BOOL isMatch = YES;
        
        for (NSString *patternComponent in self.pathComponents)
        {
            NSString *URLComponent = nil;
            if (componentIndex < [URLComponents count])
            {
                URLComponent = URLComponents[componentIndex];
            }
            else if ([patternComponent isEqualToString:@"*"])
            {
                // match /foo by /foo/*
                URLComponent = [URLComponents lastObject];
            }
            
            if ([patternComponent hasPrefix:@":"])
            {
                // this component is a variable
                NSString *variableName = [patternComponent substringFromIndex:1];
                NSString *variableValue = URLComponent;
                NSString *urlDecodedVariableValue = [variableValue JLRoutes_URLDecodedStringDecodingPlusSymbols:[JLRoutes shouldDecodePlusSymbols]];
                if ([variableName length] > 0 && [urlDecodedVariableValue length] > 0)
                {
                    variables[variableName] = urlDecodedVariableValue;
                }
            }
            else if ([patternComponent isEqualToString:@"*"])
            {
                // match wildcards
                variables[JLRouteWildcardComponentsKey] = [URLComponents subarrayWithRange:NSMakeRange(componentIndex, URLComponents.count-componentIndex)];
                isMatch = YES;
                break;
            }
            else if (![patternComponent isEqualToString:URLComponent])
            {
                // a non-variable component did not match, so this route doesn't match up - on to the next one
                isMatch = NO;
                break;
            }
            componentIndex++;
        }
        
        if (isMatch)
        {
            routeParameters = variables;
        }
    }
    
    return routeParameters;
}

- (NSString *)description
{
    return [NSString stringWithFormat:@"%@ - %@ (%@)", [super description], self.path, @(self.priority)];
}

@end
