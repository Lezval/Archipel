/*
 * TNVirtualMachineScheduler.j
 *
 * Copyright (C) 2010 Antoine Mercadal <antoine.mercadal@inframonde.eu>
 * This program is free software: you can redistribute it and/or modify
 * it under the terms of the GNU Affero General Public License as
 * published by the Free Software Foundation, either version 3 of the
 * License, or (at your option) any later version.
 *
 * This program is distributed in the hope that it will be useful,
 * but WITHOUT ANY WARRANTY; without even the implied warranty of
 * MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
 * GNU Affero General Public License for more details.
 *
 * You should have received a copy of the GNU Affero General Public License
 * along with this program.  If not, see <http://www.gnu.org/licenses/>.
 */


@import <Foundation/Foundation.j>
@import <AppKit/AppKit.j>

/*! @defgroup  sampletabmodule Module SampleTabModule
    @desc Development starting point to create a Tab module
*/
TNArchipelPushNotificationScheduler             = @"archipel:push:scheduler";

TNArchipelTypeVirtualMachineSchedule            = @"archipel:vm:scheduler";
TNArchipelTypeVirtualMachineScheduleSchedule    = @"schedule";
TNArchipelTypeVirtualMachineScheduleUnschedule  = @"unschedule";
TNArchipelTypeVirtualMachineScheduleJobs        = @"jobs";

TNArchipelJobsActions                           = [@"create", @"shutdown", @"destroy", @"suspend", @"resume", @"pause", @"reboot", @"migrate"];

/*! @ingroup sampletabmodule
    Sample tabbed module implementation
    Please respect the pragma marks as musch as possible.
*/
@implementation TNVirtualMachineScheduler : TNModule
{
    @outlet CPTextField             fieldJID;
    @outlet CPTextField             fieldName;
    @outlet CPScrollView            scrollViewTableJobs;
    @outlet CPButtonBar             buttonBarJobs;
    @outlet CPWindow                windowNewJob;
    @outlet CPSearchField           filterFieldJobs;
    @outlet CPView                  viewTableContainer;
    @outlet CPTextField             fieldNewJobComment;
    @outlet CPPopUpButton           buttonNewJobAction;
    @outlet TNCalendarView          calendarViewNewJob;
    @outlet TNTextFieldStepper      stepperHour;
    @outlet TNTextFieldStepper      stepperMinute;
    @outlet TNTextFieldStepper      stepperSecond;
    @outlet CPTabView               tabViewJobSchedule;
    @outlet CPView                  viewNewJobOneShot;
    @outlet CPView                  viewNewJobRecurent;
    @outlet TNTextFieldStepper      stepperNewRecurrentJobYear;
    @outlet TNTextFieldStepper      stepperNewRecurrentJobMonth;
    @outlet TNTextFieldStepper      stepperNewRecurrentJobDay;
    @outlet TNTextFieldStepper      stepperNewRecurrentJobHour;
    @outlet TNTextFieldStepper      stepperNewRecurrentJobMinute;
    @outlet TNTextFieldStepper      stepperNewRecurrentJobSecond;
    @outlet CPCheckBox              checkBoxEveryYear;
    @outlet CPCheckBox              checkBoxEveryMonth;
    @outlet CPCheckBox              checkBoxEveryDay;
    @outlet CPCheckBox              checkBoxEveryHour;
    @outlet CPCheckBox              checkBoxEveryMinute;
    @outlet CPCheckBox              checkBoxEverySecond;


    CPTableView                     _tableJobs;
    TNTableViewDataSource           _datasourceJobs;
    CPDate                          _scheduledDate;
}


#pragma mark -
#pragma mark Initialization

- (void)awakeFromCib
{
    [viewTableContainer setBorderedWithHexColor:@"#C0C7D2"];


    _datasourceJobs     = [[TNTableViewDataSource alloc] init];
    _tableJobs          = [[CPTableView alloc] initWithFrame:[scrollViewTableJobs bounds]];

    [scrollViewTableJobs setAutoresizingMask: CPViewWidthSizable | CPViewHeightSizable];
    [scrollViewTableJobs setAutohidesScrollers:YES];
    [scrollViewTableJobs setDocumentView:_tableJobs];

    [_tableJobs setUsesAlternatingRowBackgroundColors:YES];
    [_tableJobs setAutoresizingMask: CPViewWidthSizable | CPViewHeightSizable];
    [_tableJobs setColumnAutoresizingStyle:CPTableViewLastColumnOnlyAutoresizingStyle];
    [_tableJobs setAllowsColumnReordering:YES];
    [_tableJobs setAllowsColumnResizing:YES];
    [_tableJobs setAllowsEmptySelection:YES];
    [_tableJobs setAllowsMultipleSelection:YES];

    var columnAction    = [[CPTableColumn alloc] initWithIdentifier:@"action"],
        columnDate      = [[CPTableColumn alloc] initWithIdentifier:@"date"],
        columnComment   = [[CPTableColumn alloc] initWithIdentifier:@"comment"];

    [columnAction setWidth:120];
    [[columnAction headerView] setStringValue:@"Action"];

    [columnDate setWidth:150];
    [[columnDate headerView] setStringValue:@"Date"];

    [[columnComment headerView] setStringValue:@"Comment"];

    [_tableJobs addTableColumn:columnAction];
    [_tableJobs addTableColumn:columnDate];
    [_tableJobs addTableColumn:columnComment];

    [_datasourceJobs setTable:_tableJobs];
    [_datasourceJobs setSearchableKeyPaths:[@"comment", @"action", @"date"]];
    [_tableJobs setDataSource:_datasourceJobs];

    var buttonSchedule    = [CPButtonBar plusButton],
        buttonUnschedule  = [CPButtonBar plusButton];

    [buttonSchedule setImage:[[CPImage alloc] initWithContentsOfFile:[[CPBundle mainBundle] pathForResource:@"button-icons/button-icon-plus.png"] size:CPSizeMake(16, 16)]];
    [buttonSchedule setTarget:self];
    [buttonSchedule setAction:@selector(openNewJobWindow:)];

    [buttonUnschedule setImage:[[CPImage alloc] initWithContentsOfFile:[[CPBundle mainBundle] pathForResource:@"button-icons/button-icon-minus.png"] size:CPSizeMake(16, 16)]];
    [buttonUnschedule setTarget:self];
    [buttonUnschedule setAction:@selector(unschedule:)];

    [buttonBarJobs setButtons:[buttonSchedule, buttonUnschedule]];

    [filterFieldJobs setTarget:_datasourceJobs];
    [filterFieldJobs setAction:@selector(filterObjects:)];

    [stepperHour setMaxValue:23];

    [calendarViewNewJob setBorderedWithHexColor:@"#C0C7D2"];
    [calendarViewNewJob setDelegate:self];

    [buttonNewJobAction removeAllItems];
    [buttonNewJobAction addItemsWithTitles:TNArchipelJobsActions];


    //tabview

    var itemOneShot = [[CPTabViewItem alloc] initWithIdentifier:@"itemOneShot"];
    [itemOneShot setLabel:@"Unique"];
    [itemOneShot setView:viewNewJobOneShot];
    [tabViewJobSchedule addTabViewItem:itemOneShot];

    var itemRecurrent = [[CPTabViewItem alloc] initWithIdentifier:@"itemRecurrent"];
    [itemRecurrent setLabel:@"Recurent"];
    [itemRecurrent setView:viewNewJobRecurent];
    [tabViewJobSchedule addTabViewItem:itemRecurrent];

    var date = [CPDate date];
    [stepperNewRecurrentJobYear setMaxValue:[[date format:@"Y"] intValue] + 100];
    [stepperNewRecurrentJobYear setMinValue:[date format:@"Y"]];
    [stepperNewRecurrentJobMonth setMaxValue:12];
    [stepperNewRecurrentJobMonth setMinValue:1];
    [stepperNewRecurrentJobDay setMaxValue:31];
    [stepperNewRecurrentJobDay setMinValue:1];
    [stepperNewRecurrentJobHour setMaxValue:23];
    [stepperNewRecurrentJobHour setMinValue:0];
}


#pragma mark -
#pragma mark TNModule overrides

/*! called when module is loaded
*/
- (void)willLoad
{
    [super willLoad];

    var center = [CPNotificationCenter defaultCenter];
    [center addObserver:self selector:@selector(_didUpdateNickName:) name:TNStropheContactNicknameUpdatedNotification object:_entity];
    [center postNotificationName:TNArchipelModulesReadyNotification object:self];

    [self registerSelector:@selector(_didReceivePush:) forPushNotificationType:TNArchipelPushNotificationScheduler];

    [self getJobs];
}

/*! called when module is unloaded
*/
- (void)willUnload
{
    [super willUnload];
}

/*! called when module becomes visible
*/
- (void)willShow
{
    [super willShow];

    [fieldName setStringValue:[_entity nickname]];
    [fieldJID setStringValue:[_entity JID]];
}

/*! called when module becomes unvisible
*/
- (void)willHide
{
    [super willHide];
    [windowNewJob close];
}


/*! called by module loader when MainMenu is ready
*/
- (void)menuReady
{
    [[_menu addItemWithTitle:@"Schedule new action" action:@selector(schedule:) keyEquivalent:@""] setTarget:self];
    [[_menu addItemWithTitle:@"Unschedule selected action" action:@selector(shutdown:) keyEquivalent:@""] setTarget:self];
}


#pragma mark -
#pragma mark Notification handlers

/*! called when entity' nickname changed
    @param aNotification the notification
*/
- (void)_didUpdateNickName:(CPNotification)aNotification
{
    if ([aNotification object] == _entity)
    {
       [fieldName setStringValue:[_entity nickname]]
    }
}

/*! called when an Archipel push is received
    @param somePushInfo CPDictionary containing the push information
*/
- (BOOL)_didReceivePush:(CPDictionary)somePushInfo
{
    var sender  = [somePushInfo objectForKey:@"owner"],
        type    = [somePushInfo objectForKey:@"type"],
        change  = [somePushInfo objectForKey:@"change"],
        date    = [somePushInfo objectForKey:@"date"];

    CPLog.info(@"PUSH NOTIFICATION: from: " + sender + ", type: " + type + ", change: " + change);

    [self getJobs];

    return YES;
}



#pragma mark -
#pragma mark Utilities

// put your utilities here


#pragma mark -
#pragma mark Actions

/*! Open the new job window
    @param sender the sender of the action
*/
- (IBAction)openNewJobWindow:(id)aSender
{
    var date = [CPDate date];

    [fieldNewJobComment setStringValue:@""];
    [stepperHour setDoubleValue:[date format:@"H"]]
    [stepperMinute setDoubleValue:[date format:@"i"]]
    [stepperSecond setDoubleValue:0.0];
    [calendarViewNewJob makeSelectionWithDate:date end:date];

    [stepperNewRecurrentJobYear setDoubleValue:[date format:@"Y"]];
    [stepperNewRecurrentJobMonth setDoubleValue:[date format:@"m"]];
    [stepperNewRecurrentJobDay setDoubleValue:[date format:@"d"]];
    [stepperNewRecurrentJobHour setDoubleValue:[date format:@"H"]];
    [stepperNewRecurrentJobMinute setDoubleValue:[date format:@"i"]];
    [stepperNewRecurrentJobSecond setDoubleValue:0.0];

    [windowNewJob center];
    [windowNewJob makeKeyAndOrderFront:nil];

    [buttonNewJobAction selectItemWithTitle:@"create"];
}

/*! schedule a new job
*/
- (IBAction)schedule:(id)sender
{
    [windowNewJob close];
    [self schedule];
}

/*! unschedule the selected jobs
*/
- (IBAction)unschedule:(id)sender
{
    [self unschedule];
}

/*! handle every checkbox event
*/
- (IBAction)checkboxClicked:(id)aSender
{
    switch ([aSender tag])
    {
        case "1":
            [stepperNewRecurrentJobYear setEnabled:![aSender state]];
            break;
        case "2":
            [stepperNewRecurrentJobMonth setEnabled:![aSender state]];
            break;
        case "3":
            [stepperNewRecurrentJobDay setEnabled:![aSender state]];
            break;
        case "4":
            [stepperNewRecurrentJobHour setEnabled:![aSender state]];
            break;
        case "5":
            [stepperNewRecurrentJobMinute setEnabled:![aSender state]];
            break;
        case "6":
            [stepperNewRecurrentJobSecond setEnabled:![aSender state]];
            break;
    }
}

#pragma mark -
#pragma mark XMPP Controls

/*! ask for existing jobs
*/
- (void)getJobs
{
    var stanza = [TNStropheStanza iqWithType:@"get"];

    [stanza addChildWithName:@"query" andAttributes:{"xmlns": TNArchipelTypeVirtualMachineSchedule}];
    [stanza addChildWithName:@"archipel" andAttributes:{
        "action": TNArchipelTypeVirtualMachineScheduleJobs}];

    [_entity sendStanza:stanza andRegisterSelector:@selector(_didReceiveJobs:) ofObject:self];
}

/*! compute the answer containing the jobs
    @param aStanza TNStropheStanza containing the answer
*/
- (BOOL)_didReceiveJobs:(TNStropheStanza)aStanza
{
    if ([aStanza type] == @"result")
    {
        [_datasourceJobs removeAllObjects];

        var jobs = [aStanza childrenWithName:@"job"];

        for (var i = 0; i < [jobs count]; i++)
        {
            var job             = [jobs objectAtIndex:i],
                action          = [job valueForAttribute:@"action"],
                uid             = [job valueForAttribute:@"uid"],
                comment         = [job valueForAttribute:@"comment"],
                date            = [job valueForAttribute:@"date"],

                newJob    = [CPDictionary dictionaryWithObjectsAndKeys:action, @"action", uid, @"uid", comment, @"comment", date, @"date"];

            [_datasourceJobs addObject:newJob];
        }
        [_tableJobs reloadData];
    }
    else
    {
        [self handleIqErrorFromStanza:aStanza];
    }

    return NO;
}


/*! schedule a new job
*/
- (void)schedule
{
    if (!_scheduledDate)
    {
        [[TNGrowlCenter defaultCenter] pushNotificationWithTitle:@"Scheduler" message:@"You must select a date" icon:TNGrowlIconError];
        return;
    }

    var stanza = [TNStropheStanza iqWithType:@"get"];

    var year,
        month,
        day,
        hour,
        minute,
        second;

    if ([[tabViewJobSchedule selectedTabViewItem] identifier] == @"itemOneShot")
    {
        year    = [_scheduledDate format:@"Y"];
        month   = [_scheduledDate format:@"m"];
        day     = [_scheduledDate format:@"d"];
        hour    = [stepperHour doubleValue];
        minute  = [stepperMinute doubleValue];
        second  = [stepperSecond doubleValue];
    }
    else if ([[tabViewJobSchedule selectedTabViewItem] identifier] == @"itemRecurrent")
    {
        year    = (![checkBoxEveryYear state]) ? [stepperNewRecurrentJobYear doubleValue] : "*";
        month   = (![checkBoxEveryMonth state]) ? [stepperNewRecurrentJobMonth doubleValue] : "*";
        day     = (![checkBoxEveryDay state]) ? [stepperNewRecurrentJobDay doubleValue] : "*";
        hour    = (![checkBoxEveryHour state]) ? [stepperNewRecurrentJobHour doubleValue] : "*";
        minute  = (![checkBoxEveryMinute state]) ? [stepperNewRecurrentJobMinute doubleValue] : "*";
        second  = (![checkBoxEverySecond state]) ? [stepperNewRecurrentJobSecond doubleValue] : "*";
    }

    [stanza addChildWithName:@"query" andAttributes:{"xmlns": TNArchipelTypeVirtualMachineSchedule}];
    [stanza addChildWithName:@"archipel" andAttributes:{
        "action": TNArchipelTypeVirtualMachineScheduleSchedule,
        "comment": [fieldNewJobComment stringValue],
        "job": [buttonNewJobAction title],
        "year": year,
        "month": month,
        "day": day,
        "hour": hour,
        "minute": minute,
        "second": second}];

    [_entity sendStanza:stanza andRegisterSelector:@selector(_didScheduleJob:) ofObject:self];
}

/*! compute the scheduling results
    @param aStanza TNStropheStanza containing the answer
*/
- (BOOL)_didScheduleJob:(TNStropheStanza)aStanza
{
    if ([aStanza type] == @"result")
    {
        [[TNGrowlCenter defaultCenter] pushNotificationWithTitle:@"Scheduler" message:@"Action has been scheduled"];
    }
    else
    {
        [self handleIqErrorFromStanza:aStanza];
    }

    return NO;
}


/*! schedule a new job, but before ask user confirmation
*/
- (void)unschedule
{
    if (([_tableJobs numberOfRows] == 0) || ([_tableJobs numberOfSelectedRows] <= 0))
    {
         [CPAlert alertWithTitle:@"Error" message:@"You must select a job"];
         return;
    }

    var title = @"Unschedule Jobs",
        msg   = @"Are you sure you want to unschedule these jobs ?";

    if ([[_tableJobs selectedRowIndexes] count] < 2)
    {
        title = @"Unschedule job";
        msg   = @"Are you sure you want to unschedule this job ?";
    }

    var alert = [TNAlert alertWithTitle:title
                                message:msg
                                 target:self
                                 actions:[["Unschedule", @selector(performUnschedule:)], ["Cancel", nil]]];

    [alert setUserInfo:[_tableJobs selectedRowIndexes]];

    [alert runModal];
}

/*! schedule a new job
*/
- (void)performUnschedule:(id)userInfo
{
    var indexes = userInfo,
        objects = [_datasourceJobs objectsAtIndexes:indexes];

    [_tableJobs deselectAll];

    for (var i = 0; i < [objects count]; i++)
    {
        var job             = [objects objectAtIndex:i],
            stanza          = [TNStropheStanza iqWithType:@"set"];

        [stanza addChildWithName:@"query" andAttributes:{"xmlns": TNArchipelTypeVirtualMachineSchedule}];
        [stanza addChildWithName:@"archipel" andAttributes:{
            "action": TNArchipelTypeVirtualMachineScheduleUnschedule,
            "uid": [job objectForKey:@"uid"]}];

        [_entity sendStanza:stanza andRegisterSelector:@selector(_didUnscheduleJobs:) ofObject:self];
    }
}

/*! compute the scheduling results
    @param aStanza TNStropheStanza containing the answer
*/
- (BOOL)_didUnscheduleJobs:(TNStropheStanza)aStanza
{
    if ([aStanza type] != @"result")
        [self handleIqErrorFromStanza:aStanza];

    return NO;
}


#pragma mark -
#pragma mark Delegates

- (void)calendarView:(LPCalendarView)aCalendarView didMakeSelection:(CPDate)aStartDate end:(CPDate)anEndDate
{
    _scheduledDate = aStartDate;
}


@end



