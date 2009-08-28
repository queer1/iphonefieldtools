// Copyright 2009 Brad Sokol
// 
// Licensed under the Apache License, Version 2.0 (the "License");
// you may not use this file except in compliance with the License.
// You may obtain a copy of the License at
// 
// http://www.apache.org/licenses/LICENSE-2.0
// 
// Unless required by applicable law or agreed to in writing, software
// distributed under the License is distributed on an "AS IS" BASIS,
// WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
// See the License for the specific language governing permissions and
// limitations under the License.

//
//  FlipsideTableViewDelegate.m
//  FieldTools
//
//  Created by Brad on 2009/05/21.
//  Copyright 2009 Brad Sokol. All rights reserved.
//

#import "FlipsideTableViewDelegate.h"

#import "Camera.h"
#import "CoC.h"
#import "Notifications.h"
#import "UserDefaults.h"

// Enumerate rows in units section of table
// TODO: Can this be DRYer?
extern const NSInteger FEET_ROW;
extern const NSInteger METRES_ROW;

// Enumerate sections in UITable
// TODO: Can this be DRYer?
extern const NSInteger CAMERAS_SECTION;
extern const NSInteger UNITS_SECTION;

// Private methods
@interface FlipsideTableViewDelegate (Private)

- (void)didSelectCameraInTableView:(UITableView*) tableView atIndexPath:(NSIndexPath*)indexPath;
- (void)didSelectUnitsInTableView:(UITableView*) tableView atIndexPath:(NSIndexPath*)indexPath;
- (NSInteger)rowForDefaultCamera;
- (NSInteger)rowForDefaultUnits;

@end

@implementation FlipsideTableViewDelegate

@synthesize editing;

- (UITableViewCellAccessoryType) tableView:(UITableView*)tableView accessoryTypeForRowWithIndexPath:(NSIndexPath*)indexPath
{
	if ([indexPath section] == CAMERAS_SECTION)
	{
		if ([self isEditing])
		{
			return UITableViewCellAccessoryDisclosureIndicator;
		}
		else
		{
			NSInteger index = [[NSUserDefaults standardUserDefaults] integerForKey:FTCameraIndex];
			if ([indexPath row] == index)
			{
				return UITableViewCellAccessoryCheckmark;
			}
		}
	}
	else if ([indexPath section] == UNITS_SECTION)
	{
		bool metric = [[NSUserDefaults standardUserDefaults] boolForKey:FTMetricKey];
		if ((metric && [indexPath row] == METRES_ROW) || (!metric && [indexPath row] == FEET_ROW))
		{
			return UITableViewCellAccessoryCheckmark;
		}
	}
	
	return UITableViewCellAccessoryNone;
}

// Forward handling of row selection to appropriate helper method
// depending on whether a units or camera row was selected.
- (void)tableView:(UITableView*)tableView didSelectRowAtIndexPath:(NSIndexPath*)indexPath
{
	[tableView deselectRowAtIndexPath:indexPath
							 animated:YES];
	
	if ([indexPath section] == CAMERAS_SECTION)
	{
		if ([self isEditing])
		{
			Camera* camera = [Camera initFromDefaultsForIndex:[indexPath row]];
			if (nil == camera)
			{
				// Nil means not found. This happens when user touches the 'Add camera' row
				// which is the last one.
				CoC* coc = [CoC findFromPresets:NSLocalizedString(@"DEFAULT_COC", "35 mm")];
				camera = [[Camera alloc] initWithDescription:@"" coc:coc identifier:[Camera count]];
			}
			
			[[NSNotificationCenter defaultCenter] 
				postNotification:
					[NSNotification notificationWithName:CAMERA_SELECTED_FOR_EDIT_NOTIFICATION 
												  object:camera]];
		}
		else
		{
			[self didSelectCameraInTableView:tableView atIndexPath:indexPath];
		}
	}
	else
	{
		[self didSelectUnitsInTableView:tableView atIndexPath:indexPath];
	}
}

- (UITableViewCellEditingStyle)tableView:(UITableView*)tableView editingStyleForRowAtIndexPath:(NSIndexPath*)indexPath
{
	if ([indexPath section] == UNITS_SECTION)
	{
		return UITableViewCellEditingStyleNone;
	}
	else
	{
		int cameraCount = [Camera count];
		if ([indexPath row] < cameraCount)
		{
			// This is a camera row - allow delete if more than one camera (must have at least one)
			return cameraCount > 1 ? UITableViewCellEditingStyleDelete : UITableViewCellEditingStyleNone;
		}
		else
		{
			// This is the 'add' row
			return UITableViewCellEditingStyleInsert;
		}
	}
}

#pragma mark Helper Methods

// Handles selection of a row in the cameras section of the table view
- (void)didSelectCameraInTableView:(UITableView*) tableView atIndexPath:(NSIndexPath*)indexPath
{
	NSIndexPath* oldIndexPath = [NSIndexPath indexPathForRow:[self rowForDefaultCamera] 
												   inSection:[indexPath section]];
	
	if ([oldIndexPath row] == [indexPath row])
	{
		// User selected the currently selected camera - take no action
		return;
	}
	
	UITableViewCell* newCell = [tableView cellForRowAtIndexPath:indexPath];
	if ([newCell accessoryType] == UITableViewCellAccessoryNone)
	{
		// Selected row is not the current camera so change the selection
		[newCell setAccessoryType:UITableViewCellAccessoryCheckmark];
		
		[[NSUserDefaults standardUserDefaults] setInteger:[indexPath row]
												   forKey:FTCameraIndex];
		[[NSNotificationCenter defaultCenter] 
		 postNotification:[NSNotification notificationWithName:COC_CHANGED_NOTIFICATION object:nil]];
	}
	
	UITableViewCell* oldCell = [tableView cellForRowAtIndexPath:oldIndexPath];
	if ([oldCell accessoryType] == UITableViewCellAccessoryCheckmark)
	{
		[oldCell setAccessoryType:UITableViewCellAccessoryNone];
	}
}

// Handles select of a row in the units section of the table view
- (void)didSelectUnitsInTableView:(UITableView*) tableView atIndexPath:(NSIndexPath*)indexPath
{
	NSIndexPath* oldIndexPath = [NSIndexPath indexPathForRow:[self rowForDefaultUnits] 
												   inSection:[indexPath section]];
	
	if ([oldIndexPath row] == [indexPath row])
	{
		// User selected the currently selected units - take no action
		return;
	}
	
	UITableViewCell* newCell = [tableView cellForRowAtIndexPath:indexPath];
	if ([newCell accessoryType] == UITableViewCellAccessoryNone)
	{
		// Selectedrow is not the current units so change the selection
		[newCell setAccessoryType:UITableViewCellAccessoryCheckmark];
		
		[[NSUserDefaults standardUserDefaults] setBool:[indexPath row] == METRES_ROW
												forKey:FTMetricKey];
		[[NSNotificationCenter defaultCenter] 
		 postNotification:[NSNotification notificationWithName:UNITS_CHANGED_NOTIFICATION object:nil]];
	}
	
	UITableViewCell* oldCell = [tableView cellForRowAtIndexPath:oldIndexPath];
	if ([oldCell accessoryType] == UITableViewCellAccessoryCheckmark)
	{
		[oldCell setAccessoryType:UITableViewCellAccessoryNone];
	}
}

// Returns the row index for the current default camera
- (NSInteger)rowForDefaultCamera
{
	NSInteger index = [[NSUserDefaults standardUserDefaults] integerForKey:FTCameraIndex];
	return index;
}

// Returns the row index for the current units
- (NSInteger)rowForDefaultUnits
{
	bool metric = [[NSUserDefaults standardUserDefaults] boolForKey:FTMetricKey];
	return metric ? METRES_ROW : FEET_ROW;
}

@end