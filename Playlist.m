//
//  Movist
//
//  Created by dckim <cocoable@gmail.com>
//  Copyright 2006 cocoable. All rights reserved.
//

#import "Playlist.h"

#import "MMovie.h"
#import "MSubtitle.h"  // for auto-find-subtitle

@implementation PlaylistItem

- (id)initWithMovieURL:(NSURL*)movieURL
{
    //TRACE(@"%s \"%@\"", __PRETTY_FUNCTION__, [movieURL absoluteString]);
    if (self = [super init]) {
        _movieURL = [movieURL retain];
    }
    return self;
}

- (void)dealloc
{
    //TRACE(@"%s", __PRETTY_FUNCTION__);
    [_movieURL release];
    [_subtitleURL release];
    [super dealloc];
}

- (id)copyWithZone:(NSZone*)zone
{
    //TRACE(@"%s", __PRETTY_FUNCTION__);
    PlaylistItem* item = [[PlaylistItem alloc] initWithMovieURL:_movieURL];
    [item setSubtitleURL:_subtitleURL];
    return item;
}

////////////////////////////////////////////////////////////////////////////////
#pragma mark -

- (NSURL*)movieURL    { return _movieURL; }
- (NSURL*)subtitleURL { return _subtitleURL; }

- (void)setMovieURL:(NSURL*)movieURL
{
    //TRACE(@"%s \"%@\"", __PRETTY_FUNCTION__, [movieURL absoluteString]);
    [movieURL retain], [_movieURL release], _movieURL = movieURL;
}

- (void)setSubtitleURL:(NSURL*)subtitleURL
{
    //TRACE(@"%s \"%@\"", __PRETTY_FUNCTION__, [subtitleURL absoluteString]);
    [subtitleURL retain], [_subtitleURL release], _subtitleURL = subtitleURL;
}

////////////////////////////////////////////////////////////////////////////////
#pragma mark -

- (BOOL)isEqualToMovieURL:(NSURL*)movieURL
{
    //TRACE(@"%s \"%@\"", __PRETTY_FUNCTION__, [movieURL absoluteString]);
    return [[_movieURL absoluteString] isEqualToString:[movieURL absoluteString]];
}

@end

////////////////////////////////////////////////////////////////////////////////
#pragma mark -

@implementation Playlist

- (id)init
{
    TRACE(@"%s", __PRETTY_FUNCTION__);
    if (self = [super init]) {
        _array = [[NSMutableArray alloc] initWithCapacity:10];
        _repeatMode = REPEAT_OFF;
    }
    return self;
}

- (void)dealloc
{
    TRACE(@"%s", __PRETTY_FUNCTION__);
    [_array release];
    [super dealloc];
}

////////////////////////////////////////////////////////////////////////////////
#pragma mark -
#pragma mark add/remove

- (BOOL)containsMovieURL:(NSURL*)movieURL
{
    //TRACE(@"%s \"%@\"", __PRETTY_FUNCTION__, [movieURL absoluteString]);
    PlaylistItem* item;
    NSEnumerator* enumerator = [_array objectEnumerator];
    while (item = [enumerator nextObject]) {
        if ([item isEqualToMovieURL:movieURL]) {
            return TRUE;
        }
    }
    return FALSE;
}

- (NSString*)findSubtitlePathForMoviePath:(NSString*)moviePath
{
    //TRACE(@"%s \"%@\"", __PRETTY_FUNCTION__, moviePath);
    NSFileManager* fileManager = [NSFileManager defaultManager];
    NSString* path, *ext;
    NSString* pathWithoutExt = [moviePath stringByDeletingPathExtension];
    NSArray* extensions = [MSubtitle subtitleTypes];
    NSEnumerator* enumerator = [extensions objectEnumerator];
    while (ext = [enumerator nextObject]) {
        path = [pathWithoutExt stringByAppendingPathExtension:ext];
        if ([fileManager fileExistsAtPath:path] &&
            [fileManager isReadableFileAtPath:path]) {
            return path;
        }
    }
    return nil;
}

- (BOOL)checkMovieSeriesFile:(NSString*)path forMovieFile:(NSString*)moviePath
{
    TRACE(@"%s \"%@\" for \"%@\"", __PRETTY_FUNCTION__, path, moviePath);
    if ([path isEqualToString:moviePath]) {
        return TRUE;
    }
    
    // don't check if same extension for more flexibility
    //if (![[path pathExtension] isEqualToString:[moviePath pathExtension]]) {
    //    return FALSE;
    //}

    unsigned int length1 = [moviePath length];
    unsigned int length2 = [path length];
    unsigned int i, minSameLength = 5;
    unichar c1, c2;
    for (i = 0; i < length1 && i < length2; i++) {
        c1 = [moviePath characterAtIndex:i];
        c2 = [path characterAtIndex:i];
        if (c1 != c2) {
            return (minSameLength <= i || (isdigit(c1) && isdigit(c2)));
        }
    }
    return TRUE;
}        

////////////////////////////////////////////////////////////////////////////////
#pragma mark -

- (int)count                            { return [_array count]; }
- (PlaylistItem*)itemAtIndex:(int)index { return [_array objectAtIndex:index]; }

- (void)addFile:(NSString*)filename addSeries:(BOOL)addSeries
{
    TRACE(@"%s \"%@\" %@", __PRETTY_FUNCTION__,
          filename, addSeries ? @"addSeries" : @"only one");
    [self insertFile:filename atIndex:[_array count] addSeries:addSeries];
}

- (void)addFiles:(NSArray*)filenames
{
    TRACE(@"%s {%@}", __PRETTY_FUNCTION__, filenames);
    [self insertFiles:filenames atIndex:[_array count]];
}

- (void)addURL:(NSURL*)movieURL
{
    TRACE(@"%s %@", __PRETTY_FUNCTION__, [movieURL absoluteString]);
    [self insertURL:movieURL atIndex:[_array count]];
}

- (int)insertFile:(NSString*)filename atIndex:(unsigned int)index
        addSeries:(BOOL)addSeries
{
    TRACE(@"%s \"%@\" at %d %@", __PRETTY_FUNCTION__,
          filename, index, addSeries ? @"addSeries" : @"only one");
    BOOL isDirectory;
    NSFileManager* fileManager = [NSFileManager defaultManager];
    if (![fileManager fileExistsAtPath:filename isDirectory:&isDirectory]) {
        return 0;
    }

    if (isDirectory) {
        NSString* directory = filename;
        NSArray* contents = [fileManager directoryContentsAtPath:directory];
        NSEnumerator* enumerator = [contents objectEnumerator];
        while (filename = [enumerator nextObject]) {
            filename = [directory stringByAppendingPathComponent:filename];
            if ([filename hasAnyExtension:[MMovie movieTypes]]) {
                [self insertURL:[NSURL fileURLWithPath:filename] atIndex:index++];
            }
        }
        return [contents count];
    }
    else if (addSeries) {
        NSString* directory = [filename stringByDeletingLastPathComponent];
        NSString* movieFilename = [filename lastPathComponent];

        NSArray* contents = [fileManager directoryContentsAtPath:directory];
        NSEnumerator* enumerator = [contents objectEnumerator];
        while (filename = [enumerator nextObject]) {
            if ([filename hasAnyExtension:[MMovie movieTypes]] &&
                [self checkMovieSeriesFile:filename forMovieFile:movieFilename]) {
                [self insertURL:[NSURL fileURLWithPath:
                            [directory stringByAppendingPathComponent:filename]]
                        atIndex:index++];

                if ([filename isEqualToString:movieFilename]) {
                    _currentItem = [_array lastObject];
                }
            }
        }
        return [contents count];
    }
    else if ([filename hasAnyExtension:[MMovie movieTypes]]) {
        [self insertURL:[NSURL fileURLWithPath:filename] atIndex:index];
        return 1;
    }
    return 0;
}

- (void)insertFiles:(NSArray*)filenames atIndex:(unsigned int)index
{
    TRACE(@"%s {%@} at %d", __PRETTY_FUNCTION__, filenames, index);
    NSString* filename;
    NSEnumerator* enumerator = [filenames objectEnumerator];
    while (filename = [enumerator nextObject]) {
        index += [self insertFile:filename atIndex:index addSeries:FALSE];
    }
}

- (void)insertURL:(NSURL*)movieURL atIndex:(unsigned int)index
{
    //TRACE(@"%s \"%@\" at %d", __PRETTY_FUNCTION__, [movieURL absoluteString], index);
    if ([self containsMovieURL:movieURL]) {
        return;     // already contained
    }
    
    NSURL* subtitleURL = nil;
    if ([movieURL isFileURL]) {
        NSString* subtitlePath = [self findSubtitlePathForMoviePath:[movieURL path]];
        if (subtitlePath) {
            subtitleURL = [NSURL fileURLWithPath:subtitlePath];
        }
    }
    
    PlaylistItem* item = [[PlaylistItem alloc] initWithMovieURL:movieURL];
    [item setSubtitleURL:subtitleURL];
    [_array insertObject:item atIndex:MIN(index, [_array count])];
    
    if (_currentItem == nil) {
        _currentItem = item;    // auto-select
    }
}

- (unsigned int)moveItemsAtIndexes:(NSIndexSet*)indexes toIndex:(unsigned int)index
{
    TRACE(@"%s %@ to %d", __PRETTY_FUNCTION__, indexes, index);
    if ([indexes firstIndex] <= index && index <= [indexes lastIndex]) {
        int i, lastIndex = index;
        for (i = [indexes firstIndex]; i <= lastIndex; i++) {
            if ([indexes containsIndex:i]) {
                index--;
            }
        }
    }
    else if ([indexes lastIndex] < index) {
        index -= [indexes count];
    }

    NSArray* items = [_array objectsAtIndexes:indexes];
    [_array removeObjectsAtIndexes:indexes];

    PlaylistItem* item;
    NSEnumerator* enumerator = [items objectEnumerator];
    while (item = [enumerator nextObject]) {
        [_array insertObject:item atIndex:index++];
    }
    return index - [items count];   // new first index
}

- (void)removeItemAtIndex:(unsigned int)index
{
    TRACE(@"%s at %d", __PRETTY_FUNCTION__, index);
    if ([_array count] <= index) {
        return;
    }

    if (_currentItem == [_array objectAtIndex:index]) {
        if (index == [_array count] - 1) {
            index = [_array count] - 2;
        }
        _currentItem = (0 <= index) ? [_array objectAtIndex:index] : nil;
    }
    [_array removeObjectAtIndex:index];
}

- (void)removeItemsAtIndexes:(NSIndexSet*)indexes
{
    TRACE(@"%s %@", __PRETTY_FUNCTION__, indexes);
    [_array removeObjectsAtIndexes:indexes];

    if (![_array containsObject:_currentItem]) {
        _currentItem = nil;
    }
}

- (void)removeAllItems
{
    TRACE(@"%s", __PRETTY_FUNCTION__);
    _currentItem = nil;
    [_array removeAllObjects];
}

////////////////////////////////////////////////////////////////////////////////
#pragma mark -
#pragma mark play

- (PlaylistItem*)currentItem { return _currentItem; }
- (NSEnumerator*)itemEnumerator { return [_array objectEnumerator]; }
- (int)indexOfItem:(PlaylistItem*)item { return [_array indexOfObject:item]; }

- (void)setCurrentItemAtIndex:(unsigned int)index
{
    TRACE(@"%s %d", __PRETTY_FUNCTION__, index);
    _currentItem = [_array objectAtIndex:index];
}

- (void)setNextItem_RepeatOff:(BOOL)forward
{
    TRACE(@"%s %@", __PRETTY_FUNCTION__, forward ? @"forward" : @"backward");
    assert(0 < [_array count]);
    if (!_currentItem) {
        _currentItem = (forward) ? [_array objectAtIndex:0] :
                                   [_array objectAtIndex:[_array count] - 1];
    }
    else {
        int index = [_array indexOfObject:_currentItem];
        if (forward) {
            _currentItem = (index == [_array count] - 1) ? nil :
                                                [_array objectAtIndex:index + 1];
        }
        else {
            _currentItem = (index == 0) ? nil : [_array objectAtIndex:index - 1];
        }
    }
}

- (void)setNextItem_RepeatAll:(BOOL)forward
{
    TRACE(@"%s %@", __PRETTY_FUNCTION__, forward ? @"forward" : @"backward");
    assert(0 < [_array count]);
    if (!_currentItem) {
        _currentItem = (forward) ? [_array objectAtIndex:0] :
                                   [_array objectAtIndex:[_array count] - 1];
    }
    else {
        int index = [_array indexOfObject:_currentItem];
        if (forward) {
            index = (index < [_array count] - 1) ? (index + 1) : 0;
        }
        else {
            index = (0 < index) ? (index - 1) : [_array count] - 1;
        }
        _currentItem = [_array objectAtIndex:index];
    }
}

- (void)setNextItem_RepeatOne
{
    TRACE(@"%s", __PRETTY_FUNCTION__);
    assert(0 < [_array count]);
    if (!_currentItem) {
        _currentItem = [_array objectAtIndex:0];
    }
}

- (void)setPrevItem
{
    TRACE(@"%s", __PRETTY_FUNCTION__);
    if (0 < [_array count]) {
        switch (_repeatMode) {
            case REPEAT_OFF : [self setNextItem_RepeatOff:FALSE];   break;
            case REPEAT_ALL : [self setNextItem_RepeatAll:FALSE];   break;
            case REPEAT_ONE : [self setNextItem_RepeatOne];         break;
        }
    }
}

- (void)setNextItem
{
    TRACE(@"%s", __PRETTY_FUNCTION__);
    if (0 < [_array count]) {
        switch (_repeatMode) {
            case REPEAT_OFF : [self setNextItem_RepeatOff:TRUE];    break;
            case REPEAT_ALL : [self setNextItem_RepeatAll:TRUE];    break;
            case REPEAT_ONE : [self setNextItem_RepeatOne];         break;
        }
    }
}

////////////////////////////////////////////////////////////////////////////////
#pragma mark -
#pragma mark repeat-mode

- (unsigned int)repeatMode { return _repeatMode; }

- (void)setRepeatMode:(unsigned int)mode
{
    TRACE(@"%s %d", __PRETTY_FUNCTION__, mode);
    _repeatMode = mode;
}

@end