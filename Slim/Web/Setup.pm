package Slim::Web::Setup;

# $Id: Setup.pm,v 1.13 2003/10/14 19:13:21 dean Exp $

# Slim Server Copyright (c) 2001, 2002, 2003 Sean Adams, Slim Devices Inc.
# This program is free software; you can redistribute it and/or
# modify it under the terms of the GNU General Public License,
# version 2.

use strict;
use File::Spec::Functions qw(:ALL);
use POSIX;
use Sys::Hostname;
use Slim::Utils::Misc;
use Slim::Utils::Strings qw(string);

my %setup = ();
# Setup uses strings extensively, for many values it defaults to a certain combination of the
# preference name with other characters.  For this reason it is important to follow the naming
# convention when adding strings for preferences into strings.txt.
# In the following $groupname is replaced by the actual key used in the Groups hash and $prefname
# by the key from the Prefs hash.
# SETUP_GROUP_$groupname => the name of the group, such as would be used in a menu to select the group
#				or in the heading of the group in the web page.  Should be < 40 chars
# SETUP_GROUP_$groupname_DESC => the long description of the group, used in the web page, so length unimportant
# SETUP_$prefname => the friendly name of the preference, such as would be used in a menu to select the preference
#				or in the heading of the preference in the web page.  Should be < 40 chars.  Also
#				used when the preference changes and no change intro message was specified.
# SETUP_$prefname_DESC => the long description of the preference, used in the web page, so length unimportant
# SETUP_$prefname_CHOOSE => the label used for presentation of the input for the preference
# SETUP_$prefname_OK => the change intro message to use when the preference changes

# setup hash's keys:
# 'player' => hash of per player settings
# 'server' => hash of main server settings on the setup server web page
# 'advanced' => hash of main server settings on the setup advanced web page

# page hash's keys:
# 'preEval' => sub ref taking $client,$paramref,$pageref as parameters used to refresh a setup entry on each page load
# 'postChange' => sub ref taking $client,$paramref,$pageref as parameters
# 'isClient' => set to 1 for pages relating to a player (client)
# 'template' => template to use to build page
# 'GroupOrder' => array of preference groups to appear on page, in order
# 'Groups' => hash of preference groups on page
# 'Prefs' => hash of preferences on page
# 'parent' => parent category of current category
# 'children' => array of child categories of current category
# 'title' => friendly name to use in web page
# 'singleChildLinkText' => Text to use for a single link to the first child


# Groups hash's keys:
# 'PrefOrder' => list of prefs to appear in group, in order
# 'PrefsInTable' => set if prefs should appear in a table
# 'GroupHead' => Name of the group, usually set to string('SETUP_GROUP+$groupname'), not defaulted to anything
# 'GroupDesc' => Description of the group, usually set to string('SETUP_GROUP_$groupname_DESC'), not defaulted to anything
# 'GroupLine' => set if an <hr> should appear after the group
# 'GroupSub' => set if a submit button should appear after the group
# 'Suppress_PrefHead' => set to prevent the heading of preferences in the group from showing
# 'Suppress_PrefDesc' => set to prevent the descriptions of preferences in the group from showing
# 'Suppress_PrefLine' => set to prevent <hr>'s from appearing after preferences in the group
# 'Suppress_PrefSub' => set to prevent submit buttons from appearing after preferences in the group

# Prefs hash's' keys:
# 'onChange' => sub ref taking $client,$changeref,$paramref,$pageref,$key,$ind as parameters, fired when a preference changes
# 'isArray' => exists if setting is an array type preference
# 'arrayAddExtra' => number of extra null entries to append to end of array
# 'arrayDeleteNull' => indicates whether to delete undef and '' from array
# 'arrayDeleteValue' => value signifying a null entry in the array
# 'arrayCurrentPref' => name of preference denoting current of array
# 'arrayBasicValue' => value to add to array if all entries are removed
# 'arrayMax' => largest index in array (only needed for items which are not actually prefs)
# 'validate' => reference to validation function (will be passed value to validate) (default validateAcceptAll)
# 'validateArgs' => array of arguments to be passed to validation function (in addition to value) (no default)
# 'options' => hash of value => text pairs to be used in building a list (no default)
# 'dontSet' => flag to suppress actually changing the preference
# 'currentValue' => sub ref taking $client,$key,$ind as parameters, returns current value of preference.  Only needed for preferences which don't use Slim::Utils::Prefs
# 'noWarning' => flag to suppress change information
# 'externalValue' => sub ref taking $client,$value, $key as parameters, used to map an internal value to an external one
# 'PrefName' => friendly name of the preference (defaults to string('SETUP_$prefname')
# 'PrefDesc' => long description of the preference (defaults to string('SETUP_$prefname_DESC')
# 'PrefChoose' => label to use for input of the preference (defaults to string('SETUP_$prefname_CHOOSE')
# 'PrefSize' => size to use for text box of input (choices are 'small','medium', and 'large', default 'small')
#	Actual size to use is determined by the setup_input_txt.html template (in EN skin values are 10,20,40)
# 'ChangeButton' => Text to display on the submit button within the input for this preference
#	Defaults to string('CHANGE')
# 'inputTemplate' => template to use for the input of the preference (defaults to setup_input_sel.html
#	for preferences with 'options', setup_input_txt.html otherwise)
# 'changeIntro' => template for the change introductory text (defaults to 'string('SETUP_NEW_VALUE') string('SETUP_prefname'):')
#	for array prefs the default is 'string('SETUP_NEW_VALUE') string('SETUP_prefname') %s:' sprintf'd with array index
# 'changeMsg' => template for change value (defaults to %s), this will be sprintf'd to stick in the value
# 'changeAddlText => template for any additional text to display after a change (default '')
# 'rejectIntro' => template for the rejection introductory text (defaults to 'string('SETUP_NEW_VALUE') string('SETUP_prefname') string('SETUP_REJECTED'):')(sprintf'd with array index for array settings)
	#for array prefs the default is 'string('SETUP_NEW_VALUE') string('SETUP_prefname') %s string('SETUP_REJECTED'):' sprintf'd with array index
# 'rejectMsg' => template for rejected value message (defaults to 'string('SETUP_BAD_VALUE')%s'), this will be sprintf'd to stick in the value
# 'rejectAddlText => template for any additional text to display after a rejection (default '')

# the default values are used for keys which do not exist() for a particular preference
# for most preferences the only values to set will be 'validate', 'validateArgs', and 'options'

sub initSetupConfig {
	%setup = (
	'player' => {
		'title' => string('PLAYER_SETTINGS') #may be modified in postChange to reflect player name
		,'children' => ['additional_player']
		,'singleChildLinkText' => string('ADDITIONAL_PLAYER_SETTINGS')
		,'isClient' => 1
		,'preEval' => sub {
					my ($client,$paramref,$pageref) = @_;
					my $titleFormatMax = Slim::Utils::Prefs::clientGetArrayMax($client,'titleFormat') + $pageref->{'Prefs'}{'titleFormat'}{'arrayAddExtra'};
					if ($client->isPlayer()) {
						$pageref->{'Groups'}{'Default'}{'PrefOrder'}[1] = 'playingDisplayMode';
						$pageref->{'children'} = ['additional_player'];
						$pageref->{'GroupOrder'}[1] = 'Brightness';
					} else {
						$pageref->{'Groups'}{'Default'}{'PrefOrder'}[1] = undef;
						$pageref->{'children'} = undef;
						$pageref->{'GroupOrder'}[1] = undef;
					}
					$pageref->{'Prefs'}{'titleFormatCurr'}{'validateArgs'} = [0,$titleFormatMax,1,1];
					$pageref->{'Prefs'}{'playername'}{'validateArgs'} = [$client->defaultName()];
					$pageref->{'Groups'}{'Default'}{'PrefOrder'}[2] = undef;
					removeExtraArrayEntries($client,'titleFormat',$paramref,$pageref);
					if (Slim::Player::Sync::isSynced($client) || (scalar(Slim::Player::Sync::canSyncWith($client)) > 0))  {
						$pageref->{'Groups'}{'Default'}{'PrefOrder'}[2] = 'synchronize';
						$pageref->{'Groups'}{'Default'}{'PrefOrder'}[3] = 'syncVolume';
						my $syncGroupsRef = syncGroups($client);
						$pageref->{'Prefs'}{'synchronize'}{'options'} = $syncGroupsRef;
						$pageref->{'Prefs'}{'synchronize'}{'validateArgs'} = [$syncGroupsRef];
					} else {
						$pageref->{'Groups'}{'Default'}{'PrefOrder'}[2] = undef;
						$pageref->{'Groups'}{'Default'}{'PrefOrder'}[3] = undef;
					}
				}
		,'postChange' => sub {
					my ($client,$paramref,$pageref) = @_;
					if ($paramref->{'playername'}) {
						$pageref->{'title'} = string('PLAYER_SETTINGS') . ' ' . string('FOR') . ' ' . $paramref->{'playername'};
					}
					if (defined($client->revision)) {
						$paramref->{'versionInfo'} = string("PLAYER_VERSION") . ': ' . $client->revision;
					}
					$paramref->{'ipaddress'} = $client->ipport();
					$paramref->{'macaddress'} = $client->macaddress;
					if (Slim::Player::Client::clientCount > 1 ) {
						$pageref->{'Prefs'}{'synchronize'}{'options'} = syncGroups($client);
						if (!exists($paramref->{'synchronize'})) {
							if (Slim::Player::Sync::isSynced($client)) {
								my $master = Slim::Player::Sync::master($client);
								$paramref->{'synchronize'} = $master->id();
							} else {
								$paramref->{'synchronize'} = -1;
							}
						}
					}
					$client->update();
				}
		,'GroupOrder' => ['Default','Brightness','TitleFormats']
		#,'template' => 'setup_player.html'
		,'Groups' => {
			'Default' => {
					'PrefOrder' => ['playername','playingDisplayMode','synchronize','syncVolume'] 
				}
			,'Brightness' => {
					'PrefOrder' => ['powerOnBrightness','powerOffBrightness']
					,'PrefsInTable' => 1
					,'Suppress_PrefHead' => 1
					,'Suppress_PrefDesc' => 1
					,'Suppress_PrefLine' => 1
					,'GroupHead' => string('SETUP_GROUP_BRIGHTNESS')
					,'GroupDesc' => string('SETUP_GROUP_BRIGHTNESS_DESC')
					,'GroupLine' => 1
				}
			,'TitleFormats' => {
					'PrefOrder' => ['titleFormat']
					,'PrefsInTable' => 1
					,'Suppress_PrefHead' => 1
					,'Suppress_PrefDesc' => 1
					,'Suppress_PrefLine' => 1
					,'GroupHead' => string('SETUP_TITLEFORMAT')
					,'GroupDesc' => string('SETUP_TITLEFORMAT_DESC')
					,'GroupPrefHead' => '<tr><th>' . string('SETUP_CURRENT') . 
										'</th><th></th><th>' . string('SETUP_FORMATS') . '</th><th></th></tr>'
					,'GroupLine' => 1
				}
			}
		,'Prefs' => {
			'powerOnBrightness' => {
							'validate' => \&validateInt
							,'validateArgs' => [0,4,1,1]
							,'options' => {
									'0' => string('BRIGHTNESS_DARK')
									,'1' => string('BRIGHTNESS_DIM')
									,'2' => string('BRIGHTNESS_BRIGHT')
									,'3' => string('BRIGHTNESS_BRIGHTER')
									,'4' => string('BRIGHTNESS_BRIGHTEST')
									}
						}
			,'powerOffBrightness' => {
							'validate' => \&validateInt
							,'validateArgs' => [0,4,1,1]
							,'options' => {
									'0' => string('BRIGHTNESS_DARK')
									,'1' => string('BRIGHTNESS_DIM')
									,'2' => string('BRIGHTNESS_BRIGHT')
									,'3' => string('BRIGHTNESS_BRIGHTER')
									,'4' => string('BRIGHTNESS_BRIGHTEST')
									}
						}
			,'playername' => {
							'validate' => \&validateHasText
							,'validateArgs' => [] #will be set by preEval
							,'PrefSize' => 'medium'
						}
			,'titleFormatCurr'	=> {
							'validate' => \&validateInt
							,'validateArgs' => [] #will be set by preEval
						}
			,'playingDisplayMode' 	=> {
							'validate' => \&validateInt
							,'validateArgs' => [0,5,1,1]
							,'options' => {
									'0' => string('BLANK')
									,'1' => string('ELAPSED')
									,'2' => string('REMAINING')
									,'3' => string('PROGRESS_BAR')
									,'4' => string('ELAPSED') . ' ' . string('AND') . ' ' . string('PROGRESS_BAR')
									,'5' => string('REMAINING') . ' ' . string('AND') . ' ' . string('PROGRESS_BAR')
									}
						}
			,'synchronize' => {
							'dontSet' => 1
							,'options' => {} #filled by preEval
							,'validate' => \&validateInHash
							,'validateArgs' => [] #filled by initSetup
							,'currentValue' => sub {
									my ($client,$key,$ind) = @_;
									if (Slim::Player::Sync::isSynced($client)) {
										return $client->id();
									} else {
										return -1;
									}
								}
							,'onChange' => sub {
									my ($client,$changeref,$paramref,$pageref) = @_;
									if ($changeref->{'synchronize'}{'new'} eq -1) {
										Slim::Player::Sync::unsync($client);
									} else {
										Slim::Player::Sync::sync($client,Slim::Player::Client::getClient($changeref->{'synchronize'}{'new'}));
									}
								}
						}
			,'syncVolume' => {
							'validate' => \&validateTrueFalse  
							,'options' => {
									'1' => string('SETUP_SYNCVOLUME_ON')
									,'0' => string('SETUP_SYNCVOLUME_OFF')
								}
						}			
			,'titleFormat'		=> {
							'isArray' => 1
							,'arrayAddExtra' => 1
							,'arrayDeleteNull' => 1
							,'arrayDeleteValue' => -1
							,'arrayBasicValue' => 0
							,'arrayCurrentPref' => 'titleFormatCurr'
							,'inputTemplate' => 'setup_input_array_sel.html'
							,'validate' => \&validateInHash
							,'validateArgs' => [] #filled by initSetup
							,'options' => {} #filled by initSetup using hash_of_titleFormats()
							,'onChange' => sub {
										my ($client,$changeref,$paramref,$pageref) = @_;
										if (exists($changeref->{'titleFormat'}{'Processed'})) {
											return;
										}
										processArrayChange($client,'titleFormat',$paramref,$pageref);
										$changeref->{'titleFormat'}{'Processed'} = 1;
									}
						}
			}
		} #end of setup{'player'} hash
	,'additional_player' => {
		'title' => string('ADDITIONAL_PLAYER_SETTINGS')
		,'parent' => 'player'
		,'isClient' => 1
		,'preEval' => sub {
				my ($client,$paramref,$pageref) = @_;
				if (scalar(keys %{Slim::Hardware::IR::mapfiles()}) > 1) {  
					$pageref->{'GroupOrder'}[2] = 'IRMap';  
					$pageref->{'Prefs'}{'irmap'}{'options'} = Slim::Hardware::IR::mapfiles();  
				} else {  
					$pageref->{'GroupOrder'}[2] = undef;
				}
				my $i = 0;
				my %irsets = map {$_ => 1} Slim::Utils::Prefs::clientGetArray($client,'disabledirsets');
				foreach my $irset (sort(keys %{Slim::Hardware::IR::irfiles()})) {
					if (exists $paramref->{"irsetlist$i"} && $paramref->{"irsetlist$i"} == (exists $irsets{$irset} ? 0 : 1)) {
						delete $paramref->{"irsetlist$i"};
					}
					$i++;
				}
				$pageref->{'Prefs'}{'irsetlist'}{'arrayMax'} = $i - 1;
				if (!$paramref->{'playername'}) {
					$paramref->{'playername'} = $client->name();
				}
				if ($paramref->{'playername'}) {
					$pageref->{'title'} = string('ADDITIONAL_PLAYER_SETTINGS') . ' ' . string('FOR') . ' ' . $paramref->{'playername'};
				}
				$paramref->{'versionInfo'} = string('PLAYER_VERSION') . ': ' . $client->revision;
			}
		,'postChange' => sub {
				my ($client,$paramref,$pageref) = @_;
				my $i = 0;
				my %irsets = map {$_ => 1} Slim::Utils::Prefs::clientGetArray($client,'disabledirsets');
				Slim::Utils::Prefs::clientDelete($client,'disabledirsets');
				foreach my $irset (sort(keys %{Slim::Hardware::IR::irfiles()})) {
					if (!exists $paramref->{"irsetlist$i"}) {
						$paramref->{"irsetlist$i"} = exists $irsets{$irset} ? 0 : 1;
					}
					unless ($paramref->{"irsetlist$i"}) {
						Slim::Utils::Prefs::clientPush($client,'disabledirsets',$irset);
					}
					Slim::Hardware::IR::loadIRFile($irset);
					$i++;
				}
			}
		,'GroupOrder' => ['Default', 'IRSets', undef]
		# if more than one ir map exists the undef will be replaced by 'Default'
		,'Groups' => {
			'Default' => {
				'PrefOrder' => ['autobrightness']
			}
			,'IRSets' => {
				'PrefOrder' => ['irsetlist']
				,'PrefsInTable' => 1
				,'Suppress_PrefHead' => 1
				,'Suppress_PrefDesc' => 1
				,'Suppress_PrefLine' => 1
				,'Suppress_PrefSub' => 1
				,'GroupHead' => string('SETUP_GROUP_IRSETS')
				,'GroupDesc' => string('SETUP_GROUP_IRSETS_DESC')
				,'GroupLine' => 1
				,'GroupSub' => 1
			}
			,'IRMap' => {
				'PrefOrder' => ['irmap']
			}
		}
		,'Prefs' => {
			'irmap' => {
				'validate' => \&validateInHash  
				,'validateArgs' => [\&Slim::Hardware::IR::mapfiles,1]  
				,'options' => undef #will be set by preEval  
			},
			'autobrightness' => {
				'validate' => \&validateTrueFalse  
				,'options' => {
						'1' => string('SETUP_AUTOBRIGHTNESS_ON')
						,'0' => string('SETUP_AUTOBRIGHTNESS_OFF')
					}
			}
			,'irsetlist' => {
				'isArray' => 1
				,'dontSet' => 1
				,'validate' => \&validateTrueFalse
				,'inputTemplate' => 'setup_input_array_chk.html'
				,'arrayMax' => undef #set in preEval
				,'changeMsg' => string('SETUP_IRSETLIST_CHANGE')
				,'externalValue' => sub {
							my ($client,$value,$key) = @_;
							if ($key =~ /\D+(\d+)$/) {
								return Slim::Hardware::IR::irfileName((sort(keys %{Slim::Hardware::IR::irfiles()}))[$1]);
							} else {
								return $value;
							}
						}
			}
		}
	} # end of setup{'ADDITIONAL_PLAYER'} hash
			
	,'server' => {
		'children' => ['interface','behavior','formats','formatting','security','performance','network','debug']
		,'title' => string('SERVER_SETTINGS')
		,'singleChildLinkText' => string('ADDITIONAL_SERVER_SETTINGS')
		,'preEval' => sub {
				my ($client,$paramref,$pageref) = @_;
				if (Slim::Music::iTunes::canUseiTunesLibrary()) {
					$pageref->{'GroupOrder'}[1] = 'itunes';
					$pageref->{'Groups'}{'Default'}{'PrefOrder'}[0] = undef;
				} else {
					$pageref->{'GroupOrder'}[1] = undef;
					$pageref->{'Groups'}{'Default'}{'PrefOrder'}[0] = 'mp3dir';
				}
				if (Slim::Music::iTunes::useiTunesLibrary()) {
					$pageref->{'Groups'}{'Default'}{'PrefOrder'}[2] = undef;
				} else {
					$pageref->{'Groups'}{'Default'}{'PrefOrder'}[2] = 'rescan';
				}
				if (Slim::Music::MoodLogic::canUseMoodLogic()) {
					$pageref->{'GroupOrder'}[2] = 'moodlogic';
				} else {
					$pageref->{'GroupOrder'}[2] = undef;
				}

				$paramref->{'versionInfo'} = string('SERVER_VERSION') . ': ' . $::VERSION;
				$paramref->{'newVersion'} = $::newVersion;
			}
		,'GroupOrder' => ['language', undef, undef, 'Default']
			#if able to use iTunesLibrary then undef at [1] will be replaced by 'iTunes'
		#,'template' => 'setup_server.html'
		,'Groups' => {
				'language' => {
						'PrefOrder' => ['language']
						},
				'itunes' => {
						'PrefOrder' => ['itunes','mp3dir']
						,'PrefsInTable' => 1
						,'Suppress_PrefHead' => 1
						,'Suppress_PrefDesc' => 1
						,'Suppress_PrefLine' => 1
						,'Suppress_PrefSub' => 1
						,'GroupHead' => string('SETUP_ITUNES')
						,'GroupDesc' => string('SETUP_ITUNES_DESC')
						,'GroupLine' => 1
						,'GroupSub' => 1
						},
                                'moodlogic' => {
                                                'PrefOrder' => ['moodlogic']
                                                ,'PrefsInTable' => 1
                                                ,'Suppress_PrefHead' => 1
                                                ,'Suppress_PrefDesc' => 1
                                                ,'Suppress_PrefLine' => 1
                                                ,'Suppress_PrefSub' => 1
                                                ,'GroupHead' => string('SETUP_MOODLOGIC')
                                                ,'GroupDesc' => string('SETUP_MOODLOGIC_DESC')
                                                ,'GroupLine' => 1
                                                ,'GroupSub' => 1
                                                },
				'Default' => {
						'PrefOrder' => [undef,'playlistdir',undef]
						#if not able to use iTunesLibrary then undef at [0] will be replaced by 'mp3dir'
						#if not using iTunesLibrary then undef at [2] will be replaced by 'rescan'
						}
			}
		,'Prefs' => {
				'language'	=> {
							'validate' => \&validateInHash
							,'validateArgs' => [\&Slim::Utils::Strings::hash_of_languages]
							,'options' => undef #filled by initSetup using Slim::Utils::Strings::hash_of_languages()
						}
				,'itunes'	=> {
							'validate' => \&validateITunes
							,'changeIntro' => ""
							,'options' => {
									'1' => string('USE_ITUNES')
									,'0' => string('DONT_USE_ITUNES')
									}
							,'inputTemplate' => 'setup_input_radio.html'
							,'changeoptions' => {
									'1' => string('USING_ITUNES')
									,'0' => 0
									}
							,'PrefSize' => 'large'
						}
                                ,'moodlogic'    => {
                                                        'onChange' => sub {
                                                                        my ($client,$changeref,$paramref,$pageref) = @_;
                                                                        if (defined $changeref->{'moodlogic'}{'new'} &&
                                                                            defined $changeref->{'moodlogic'}{'old'}) {

                                                                            if ($changeref->{'moodlogic'}{'new'} eq "1" &&
                                                                                    $changeref->{'moodlogic'}{'old'} eq "0") {
                                                                                    Slim::Music::MoodLogic::startScan();
                                                                            } elsif ($changeref->{'moodlogic'}{'new'} eq "0" &&
                                                                                    $changeref->{'moodlogic'}{'old'} eq "1") {
                                                                                    Slim::Music::MusicFolderScan::startScan();
                                                                            }
                                                                        }
                                                                    }
                                                            ,'changeIntro' => ""
                                                            ,'options' => {
                                                                       '1' => string('USE_MOODLOGIC')
                                                                       ,'0' => string('DONT_USE_MOODLOGIC')
                                                                       }
                                                       ,'inputTemplate' => 'setup_input_radio.html'
                                                       ,'PrefSize' => 'large'
                                                    }
				,'mp3dir'	=> {
							'validate' => \&validateIsMP3Dir
							,'changeIntro' => string('SETUP_OK_USING')
							,'rejectMsg' => string('SETUP_BAD_DIRECTORY')
							,'PrefSize' => 'large'
						}
				,'playlistdir'	=> {
							'validate' => \&validateIsDir
							,'validateArgs' => [1]
							,'changeIntro' => string('SETUP_PLAYLISTDIR_OK')
							,'rejectMsg' => string('SETUP_BAD_DIRECTORY')
							,'PrefSize' => 'large'
						}
				,'rescan' => {
							'validate' => \&validateAcceptAll
							,'onChange' => sub {
											Slim::Music::MusicFolderScan::startScan();
										}
							,'inputTemplate' => 'setup_input_submit.html'
							,'changeIntro' => string('RESCANNING')
							,'ChangeButton' => string('SETUP_RESCAN_BUTTON')
							,'dontSet' => 1
							,'changeMsg' => ''
						}
			}
		} #end of setup{'server'} hash
	,'plugins' => {
		'title' => string('PLUGINS')
		,'parent' => 'server'
		,'preEval' => sub {
				my ($client,$paramref,$pageref) = @_;
				my $i = 0;
				my %plugins = map {$_ => 1} Slim::Utils::Prefs::getArray('disabledplugins');
				my $pluginlistref = Slim::Buttons::Plugins::installedPlugins();
				foreach my $plugin (sort {$pluginlistref->{$a} cmp $pluginlistref->{$b}}(keys %{$pluginlistref})) {
					if (exists $paramref->{"pluginlist$i"} && $paramref->{"pluginlist$i"} == (exists $plugins{$plugin} ? 0 : 1)) {
						delete $paramref->{"pluginlist$i"};
					}
					$i++;
				}
				$pageref->{'Prefs'}{'pluginlist'}{'arrayMax'} = $i - 1;
			}
		,'postChange' => sub {
				my ($client,$paramref,$pageref) = @_;
				my $i = 0;
				my %plugins = map {$_ => 1} Slim::Utils::Prefs::getArray('disabledplugins');
				Slim::Utils::Prefs::delete('disabledplugins');
				my $pluginlistref = Slim::Buttons::Plugins::installedPlugins();
				foreach my $plugin (sort {$pluginlistref->{$a} cmp $pluginlistref->{$b}}(keys %{$pluginlistref})) {
					if (!exists $paramref->{"pluginlist$i"}) {
						$paramref->{"pluginlist$i"} = exists $plugins{$plugin} ? 0 : 1;
					}
					unless ($paramref->{"pluginlist$i"}) {
						Slim::Utils::Prefs::push('disabledplugins',$plugin);
					}
					$i++;
				}
				foreach my $group (Slim::Utils::Prefs::getArray('disabledplugins')) {
					delGroup('plugins',$group,1);
				}
				Slim::Buttons::Plugins::addSetupGroups();
			}
		,'GroupOrder' => ['Default']
		# if more than one ir map exists the undef will be replaced by 'Default'
		,'Groups' => {
				'Default' => {
					'PrefOrder' => ['pluginlist']
					,'PrefsInTable' => 1
					,'Suppress_PrefHead' => 1
					,'Suppress_PrefDesc' => 1
					,'Suppress_PrefLine' => 1
					,'Suppress_PrefSub' => 1
					,'GroupHead' => string('SETUP_GROUP_PLUGINS')
					,'GroupDesc' => string('SETUP_GROUP_PLUGINS_DESC')
					,'GroupLine' => 1
					,'GroupSub' => 1
				}
			}
		,'Prefs' => {
				'pluginlist' => {
				'isArray' => 1
				,'dontSet' => 1
				,'validate' => \&validateTrueFalse
				,'inputTemplate' => 'setup_input_array_chk.html'
				,'arrayMax' => undef #set in preEval
				,'changeMsg' => string('SETUP_PLUGINLIST_CHANGE')
				,'externalValue' => sub {
							my ($client,$value,$key) = @_;
							if ($key =~ /\D+(\d+)$/) {
								my $pluginlistref = Slim::Buttons::Plugins::installedPlugins();
								return $pluginlistref->{(sort {$pluginlistref->{$a} cmp $pluginlistref->{$b}} (keys %{$pluginlistref}))[$1]};
							} else {
								return $value;
							}
						}
				}
			}
		} #end of setup{'plugins'}
	,'interface' => {
		'title' => string('INTERFACE_SETTINGS')
		,'parent' => 'server'
		,'preEval' => sub {
					my ($client,$paramref,$pageref) = @_;
					$pageref->{'Prefs'}{'skin'}{'options'} = {skins(1)};
					$pageref->{'Prefs'}{'menuItemAction'}{'arrayMax'} = Slim::Utils::Prefs::getArrayMax('menuItem');
					my $i = 0;
					foreach my $nonItem (Slim::Buttons::Home::unusedMenuOptions()) {
						$paramref->{'nonMenuItem' . $i++} = $nonItem;
					}
					$pageref->{'Prefs'}{'nonMenuItem'}{'arrayMax'} = $i - 1;
					$pageref->{'Prefs'}{'nonMenuItemAction'}{'arrayMax'} = $i - 1;
					$pageref->{'Prefs'}{'coverArt'}{'validateArgs'} = [(defined(Slim::Utils::Prefs::get('coverArt'))) ? Slim::Utils::Prefs::get('coverArt') : ''];
					$pageref->{'Prefs'}{'coverThumb'}{'validateArgs'} = [(defined(Slim::Utils::Prefs::get('coverThumb'))) ? Slim::Utils::Prefs::get('coverThumb') : ''];
					removeExtraArrayEntries($client,'menuItem',$paramref,$pageref);
				}
		,'postChange' => sub {
					my ($client,$paramref,$pageref) = @_;
					my $i = 0;
					#refresh paramref for menuItem array
					foreach my $menuitem (Slim::Utils::Prefs::getArray('menuItem')) {
						$paramref->{'menuItem' . $i++} = $menuitem;
					}
					$pageref->{'Prefs'}{'menuItemAction'}{'arrayMax'} = $i - 1;
					while (exists $paramref->{'menuItem' . $i}) {
						delete $paramref->{'menuItem' . $i++};
					}
					#refresh paramref for nonMenuItem array
					$i = 0;
					foreach my $nonItem (Slim::Buttons::Home::unusedMenuOptions()) {
						$paramref->{'nonMenuItem' . $i++} = $nonItem;
					}
					$pageref->{'Prefs'}{'nonMenuItem'}{'arrayMax'} = $i - 1;
					$pageref->{'Prefs'}{'nonMenuItemAction'}{'arrayMax'} = $i - 1;
					while (exists $paramref->{'nonMenuItem' . $i}) {
						delete $paramref->{'nonMenuItem' . $i++};
					}
				}
		,'GroupOrder' => ['MenuItems','NonMenuItems','Default']
		,'Groups' => {
			'Default' => {
					'PrefOrder' => ['skin','itemsPerPage','refreshRate','coverArt','coverThumb']
				}
			,'MenuItems' => {
					'PrefOrder' => ['menuItem']
					,'PrefsInTable' => 1
					,'Suppress_PrefHead' => 1
					,'Suppress_PrefDesc' => 1
					,'Suppress_PrefLine' => 1
					,'Suppress_PrefSub' => 1
					,'GroupHead' => string('SETUP_GROUP_MENUITEMS')
					,'GroupDesc' => string('SETUP_GROUP_MENUITEMS_DESC')
				}
			,'NonMenuItems' => {
					'PrefOrder' => ['nonMenuItem']
					,'PrefsInTable' => 1
					,'Suppress_PrefHead' => 1
					,'Suppress_PrefDesc' => 1
					,'Suppress_PrefLine' => 1
					,'Suppress_PrefSub' => 1
					,'GroupHead' => ''
					,'GroupDesc' => string('SETUP_GROUP_NONMENUITEMS_INTRO')
					,'GroupLine' => 1
				}
			}
		,'Prefs' => {
			'menuItem'	=> {
						'isArray' => 1
						,'arrayDeleteNull' => 1
						,'arrayDeleteValue' => ''
						,'arrayBasicValue' => 'NOW_PLAYING'
						,'inputTemplate' => 'setup_input_array_udr.html'
						,'validate' => \&validateInHash
						,'validateArgs' => [\&Slim::Buttons::Home::menuOptions]
						,'externalValue' => sub {
										my ($client,$value) = @_;
										if (Slim::Utils::Strings::stringExists($value)) {
											return string($value);
										} else {
											return $value;
										}
									}
						,'onChange' => sub {
									my ($client,$changeref,$paramref,$pageref) = @_;
									#Handle all changed items whenever the first one is encountered
									#then set 'Processed' so that the changes aren't repeated
									if (exists($changeref->{'menuItem'}{'Processed'})) {
										return;
									}
									processArrayChange($client,'menuItem',$paramref,$pageref);
									Slim::Buttons::Home::updateMenu();
									$changeref->{'menuItem'}{'Processed'} = 1;
								}
					}
			,'menuItemAction' => {
						'isArray' => 1
						,'dontSet' => 1
						,'arrayMax' => undef #set in preEval
						,'noWarning' => 1
						,'onChange' => sub {
									my ($client,$changeref,$paramref,$pageref) = @_;
									#Handle all changed items whenever the first one is encountered
									#then set 'Processed' so that the changes aren't repeated
									if (exists($changeref->{'menuItemAction'}{'Processed'})) {
										return;
									}
									my $i;
									for ($i = Slim::Utils::Prefs::getArrayMax('menuItem'); $i >= 0; $i--) {
										if (exists $changeref->{'menuItemAction' . $i}) {
											my $newval = $changeref->{'menuItemAction' . $i}{'new'};
											my $tempItem = Slim::Utils::Prefs::getInd('menuItem',$i);
											if (defined $newval) {
												if ($newval eq 'Remove') {
													Slim::Utils::Prefs::delete('menuItem',$i);
												} elsif ($newval eq 'Up' && $i > 0) {
													Slim::Utils::Prefs::set('menuItem',Slim::Utils::Prefs::getInd('menuItem',$i - 1),$i);
													Slim::Utils::Prefs::set('menuItem',$tempItem,$i - 1);
												} elsif ($newval eq 'Down' && $i < Slim::Utils::Prefs::getArrayMax('menuItem')) {
													Slim::Utils::Prefs::set('menuItem',Slim::Utils::Prefs::getInd('menuItem',$i + 1),$i);
													Slim::Utils::Prefs::set('menuItem',$tempItem,$i + 1);
												}
											}
										}
									}
									if (Slim::Utils::Prefs::getArrayMax('menuItem') < 0) {
										Slim::Utils::Prefs::set('menuItem',$pageref->{'Prefs'}{'menuItem'}{'arrayBasicValue'},0);
									}
									Slim::Buttons::Home::updateMenu();
									$changeref->{'menuItemAction'}{'Processed'} = 1;
								}
					}
			,'nonMenuItem'	=> {
						'isArray' => 1
						,'dontSet' => 1
						,'arrayMax' => undef #set in preEval
						,'noWarning' => 1
						,'inputTemplate' => 'setup_input_array_add.html'
						,'externalValue' => sub {
										my ($client,$value) = @_;
										if (Slim::Utils::Strings::stringExists($value)) {
											return string($value);
										} else {
											return $value;
										}
									}
					}
			,'nonMenuItemAction' => {
						'isArray' => 1
						,'dontSet' => 1
						,'arrayMax' => undef #set in preEval
						,'noWarning' => 1
						,'onChange' => sub {
									my ($client,$changeref,$paramref,$pageref) = @_;
									#Handle all changed items whenever the first one is encountered
									#then set 'Processed' so that the changes aren't repeated
									if (exists($changeref->{'menuItemAction'}{'Processed'})) {
										return;
									}
									my $i;
									for ($i = $pageref->{'Prefs'}{'nonMenuItemAction'}{'arrayMax'}; $i >= 0; $i--) {
										if (exists $changeref->{'nonMenuItemAction' . $i}) {
											if ($changeref->{'nonMenuItemAction' . $i}{'new'} eq 'Add') {
												Slim::Utils::Prefs::push('menuItem',$paramref->{'nonMenuItem' . $i});
											}
										}
									}
									Slim::Buttons::Home::updateMenu();
									$changeref->{'nonMenuItemAction'}{'Processed'} = 1;
								}
					}
			,'skin'		=> {
						'validate' => \&validateInHash
						,'validateArgs' => [\&skins]
						,'options' => undef #filled by initSetup using skins()
						,'changeIntro' => string('SETUP_SKIN_OK')
						,'changeAddlText' => string('HIT_RELOAD')
					}
			,'itemsPerPage'	=> {
						'validate' => \&validateInt
						,'validateArgs' => [1,undef,1]
					}
			,'refreshRate'	=> {
						'validate' => \&validateInt
						,'validateArgs' => [2,undef,1]
					}
			,'coverArt' => {
						'validate' => \&validateHasText
						,'PrefSize' => 'large'
					}
			,'coverThumb' => {
						'validate' => \&validateHasText
						,'PrefSize' => 'large'
					}
			}
		}# end of setup{'interface'} hash
	,'formats' => {
		'title' => string('FORMATS_SETTINGS')
		,'parent' => 'server'
		,'GroupOrder' => ['Default']
		,'Groups' => {
			'Default' => {
					'PrefOrder' => [ 'transcode-mov', 'transcode-wav', 'transcode-ogg']
				}
			}
		,'Prefs' => {
			'transcode-ogg' => {
						'validate' => \&validateTrueFalse
						,'options' => {
								'1' => string('SETUP_TRANSCODE-OGG_1')
								,'0' => string('SETUP_TRANSCODE-OGG_0')
							}
					}
			,'transcode-wav' => {
						'validate' => \&validateTrueFalse
						,'options' => {
								'1' => string('SETUP_TRANSCODE-WAV_1')
								,'0' => string('SETUP_TRANSCODE-WAV_0')
							}
					}
			,'transcode-mov' => {
						'validate' => \&validateTrueFalse
						,'options' => {
								'1' => string('SETUP_TRANSCODE-MOV_1')
								,'0' => string('SETUP_TRANSCODE-MOV_0')
							}
					}
			}
		} #end of setup{'behavior'} hash
	,'behavior' => {
		'title' => string('BEHAVIOR_SETTINGS')
		,'parent' => 'server'
		,'GroupOrder' => ['Default']
		,'Groups' => {
			'Default' => {
					'PrefOrder' => ['screensaverjump','screensavertimeout','displaytexttimeout'
							,'composerInArtists','playtrackalbum','artistinalbumsearch', 'ignoredarticles','filesort'
							,'persistPlaylists','reshuffleOnRepeat','saveShuffled',
							,'savehistory','historylength','checkVersion']
				}
			}
		,'Prefs' => {
			'filesort' => {
						'validate' => \&validateTrueFalse
						,'options' => {
								'0' => string('SORTID3')
								,'1' => string('SORTBYFILENAME')
								}
					}
			,'screensaverjump'	=> {
						'validate' => \&validateTrueFalse
						,'options' => {
								'0' => string('SCREENSAVERJUMP_BACK')
								,'1' => string('SCREENSAVERJUMP_STAY')
							}
					}
			,'screensavertimeout' => {
						'validate' => \&validateNumber
						,'validateArgs' => [0,undef,1]
				}
			,'displaytexttimeout' => {
						'validate' => \&validateNumber
						,'validateArgs' => [0.1,undef,1]
				}
			,'ignoredarticles' => {
						'validate' => \&validateAcceptAll
						,'PrefSize' => 'large'
					}
			,'playtrackalbum' => {
						'validate' => \&validateTrueFalse
						,'options' => {
								'1' => string('SETUP_PLAYTRACKALBUM_1')
								,'0' => string('SETUP_PLAYTRACKALBUM_0')
								}
					}
			,'composerInArtists' => {
						'validate' => \&validateTrueFalse
						,'options' => {
								'1' => string('SETUP_COMPOSERINARTISTS_1')
								,'0' => string('SETUP_COMPOSERINARTISTS_0')
								}
					}
			,'artistinalbumsearch' => {
						'validate' => \&validateTrueFalse
						,'options' => {
								'1' => string('SETUP_ARTISTINALBUMSEARCH_1')
								,'0' => string('SETUP_ARTISTINALBUMSEARCH_0')
								}
					}
			,'persistPlaylists' => {
						'validate' => \&validateTrueFalse
						,'options' => {
								'1' => string('SETUP_PERSISTPLAYLISTS_1')
								,'0' => string('SETUP_PERSISTPLAYLISTS_0')
							}
					}
			,'reshuffleOnRepeat' => {
						'validate' => \&validateTrueFalse
						,'options' => {
								'1' => string('SETUP_RESHUFFLEONREPEAT_1')
								,'0' => string('SETUP_RESHUFFLEONREPEAT_0')
							}
					}
			,'saveShuffled' => {
						'validate' => \&validateTrueFalse
						,'options' => {
								'1' => string('SETUP_SAVESHUFFLED_1')
								,'0' => string('SETUP_SAVESHUFFLED_0')
							}
					}
			,'savehistory' => {
						'validate' => \&validateTrueFalse
						,'options' => {
								'1' => string('SETUP_SAVEHISTORY_1')
								,'0' => string('SETUP_SAVEHISTORY_0')
							}
					}
			,'historylength' => {
						'validate' => \&validateInt
						,'validateArgs' => [0,undef,1]
					}
			,'checkVersion' => {
						'validate' => \&validateTrueFalse
						,'options' => {
								'1' => string('SETUP_CHECKVERSION_1')
								,'0' => string('SETUP_CHECKVERSION_0')
							}
					}
			}
		} #end of setup{'behavior'} hash
	,'formatting' => {
		'title' => string('FORMATTING_SETTINGS')
		,'parent' => 'server'
		,'preEval' => sub {
					my ($client,$paramref,$pageref) = @_;
					removeExtraArrayEntries($client,'titleFormat',$paramref,$pageref);
				}
		,'GroupOrder' => ['Default','TitleFormats']
		,'Groups' => {
			'Default' => {
					'PrefOrder' => ['longdateFormat','shortdateFormat','timeFormat']
				}
			,'TitleFormats' => {
					'PrefOrder' => ['titleFormat']
					,'PrefsInTable' => 1
					,'Suppress_PrefHead' => 1
					,'Suppress_PrefDesc' => 1
					,'Suppress_PrefLine' => 1
					,'Suppress_PrefSub' => 1
					,'GroupHead' => string('SETUP_TITLEFORMAT')
					,'GroupDesc' => string('SETUP_GROUP_TITLEFORMATS_DESC')
					,'GroupPrefHead' => '<tr><th>' . string('SETUP_CURRENT') .
									    '</th><th></th><th>' . string('SETUP_FORMATS') .
									    '</th><th></th></tr>'
					,'GroupLine' => 1
					,'GroupSub' => 1
				}
			}
		,'Prefs' => {
			'titleFormatWeb' => {
						'validate' => \&validateInHash
						,'validateArgs' => [\&hash_of_titleFormats]
						#,'options' => undef #filled by initSetup using hash_of_titleFormats()
					}
			,'titleFormat'	=> {
						'isArray' => 1
						,'arrayAddExtra' => 1
						,'arrayDeleteNull' => 1
						,'arrayDeleteValue' => ''
						,'arrayBasicValue' => 0
						,'arrayCurrentPref' => 'titleFormatWeb'
						,'PrefSize' => 'large'
						,'inputTemplate' => 'setup_input_array_txt.html'
						,'validate' => \&validateFormat
						,'changeAddlText' => 'Format will be changed for any clients using this setting'
						,'onChange' => sub {
									my ($client,$changeref,$paramref,$pageref) = @_;
									if (exists($changeref->{'titleFormat'}{'Processed'})) {
										return;
									}
									processArrayChange($client,'titleFormat',$paramref,$pageref);
									fillTitleFormatOptions();
									$changeref->{'titleFormat'}{'Processed'} = 1;
								}
					}
			,"longdateFormat" => {
						'validate' => \&validateInHash
						,'validateArgs' => [] # set in initSetup
						,'options' => { #WWWW is the name of the day of the week
								#WWW is the abbreviation of the name of the day of the week
								#MMMM is the full month name
								#MMM is the abbreviated month name
								#DD is the day of the month
								#YYYY is the 4 digit year
								#YY is the 2 digit year
								q(%A, %B |%d, %Y)	=> "WWWW, MMMM DD, YYYY"
								,q(%a, %b |%d, %Y)	=> "WWW, MMM DD, YYYY"
								,q(%a, %b |%d, '%y)	=> "WWW, MMM DD, 'YY"
								,q(%A, |%d %B %Y)	=> "WWWW, DD MMMM YYYY"
								,q(%A, |%d. %B %Y)	=> "WWWW, DD. MMMM YYYY"
								,q(%a, |%d %b %Y)	=> "WWW, DD MMM YYYY"
								,q(%a, |%d. %b %Y)	=> "WWW, DD. MMM YYYY"
								,q(%A |%d %B %Y)		=> "WWWW DD MMMM YYYY"
								,q(%A |%d. %B %Y)	=> "WWWW DD. MMMM YYYY"
								,q(%a |%d %b %Y)		=> "WWW DD MMM YYYY"
								,q(%a |%d. %b %Y)	=> "WWW DD. MMM YYYY"
								}
					}
			,"shortdateFormat" => {
						'validate' => \&validateInHash
						,'validateArgs' => [] # set in initSetup
						,'options' => { #MM is the month of the year
								#DD is the day of the year
								#YYYY is the 4 digit year
								#YY is the 2 digit year
								q(%m/%d/%Y)	=> "MM/DD/YYYY"
								,q(%m/%d/%y)	=> "MM/DD/YY"
								,q(%m-%d-%Y)	=> "MM-DD-YYYY"
								,q(%m-%d-%y)	=> "MM-DD-YY"
								,q(%m.%d.%Y)	=> "MM.DD.YYYY"
								,q(%m.%d.%y)	=> "MM.DD.YY"
								,q(%d/%m/%Y)	=> "DD/MM/YYYY"
								,q(%d/%m/%y)	=> "DD/MM/YY"
								,q(%d-%m-%Y)	=> "DD-MM-YYYY"
								,q(%d-%m-%y)	=> "DD-MM-YY"
								,q(%d.%m.%Y)	=> "DD.MM.YYYY"
								,q(%d.%m.%y)	=> "DD.MM.YY"
								,q(%Y-%m-%d)	=> "YYYY-MM-DD (ISO)"
								}
					}
			,"timeFormat" => {
						'validate' => \&validateInHash
						,'validateArgs' => [] # set in initSetup
						,'options' => { #hh is hours
								#h is hours (leading zero removed)
								#mm is minutes
								#ss is seconds
								#pm is either AM or PM
								#anything at the end in parentheses is just a comment
								q(%I:%M:%S %p)	=> "hh:mm:ss pm (12h)"
								,q(%I:%M %p)	=> "hh:mm pm (12h)"
								,q(%H:%M:%S)	=> "hh:mm:ss (24h)"
								,q(%H:%M)	=> "hh:mm (24h)"
								,q(%H.%M.%S)	=> "hh.mm.ss (24h)"
								,q(%H.%M)	=> "hh.mm (24h)"
								,q(%H,%M,%S)	=> "hh,mm,ss (24h)"
								,q(%H,%M)	=> "hh,mm (24h)"
								# no idea what the separator between minutes and seconds should be here
								,q(%Hh%M:%S)	=> "hh'h'mm:ss (24h 03h00:00 15h00:00)"
								,q(%Hh%M)	=> "hh'h'mm (24h 03h00 15h00)"
								,q(|%I:%M:%S %p)	=> "h:mm:ss pm (12h)"
								,q(|%I:%M %p)		=> "h:mm pm (12h)"
								,q(|%H:%M:%S)		=> "h:mm:ss (24h)"
								,q(|%H:%M)		=> "h:mm (24h)"
								,q(|%H.%M.%S)		=> "h.mm.ss (24h)"
								,q(|%H.%M)		=> "h.mm (24h)"
								,q(|%H,%M,%S)		=> "h,mm,ss (24h)"
								,q(|%H,%M)		=> "h,mm (24h)"
								# no idea what the separator between minutes and seconds should be here
								,q(|%Hh%M:%S)		=> "h'h'mm:ss (24h 03h00:00 15h00:00)"
								,q(|%Hh%M)		=> "h'h'mm (24h 03h00 15h00)"
								}
					}
			}
		} #end of setup{'formatting'} hash
	,'security' => {
		'title' => string('SECURITY_SETTINGS')
		,'parent' => 'server'
		,'GroupOrder' => ['BasicAuth','Default']
		,'Groups' => {
			'Default' => {
					'PrefOrder' => ['filterHosts', 'allowedHosts']
				}
			,'BasicAuth' => {
					'PrefOrder' => ['authorize','username','password']
					,'Suppress_PrefSub' => 1
					,'GroupSub' => 1
					,'GroupLine' => 1
					,'Suppress_PrefLine' => 1
				}
			}
		,'Prefs' => {
			'authorize' => {
						'validate' => \&validateTrueFalse
						,'options' => {
								'0' => string('SETUP_NO_AUTHORIZE')
								,'1' => string('SETUP_AUTHORIZE')
								}
					}
			,'username' => {
						'validate' => \&validateAcceptAll
						,'PrefSize' => 'large'
					}
			,'password' => {
						'validate' => \&validatePassword
						,'inputTemplate' => 'setup_input_passwd.html'
						,'changeMsg' => string('SETUP_PASSWORD_CHANGED')
						,'PrefSize' => 'large'
					}
			,'filterHosts' => {
						
						'validate' => \&validateTrueFalse
						,'PrefHead' => string('SETUP_IPFILTER_HEAD')
						,'PrefDesc' => string('SETUP_IPFILTER_DESC')
						,'options' => {
								'0' => string('SETUP_NO_IPFILTER')
								,'1' => string('SETUP_IPFILTER')
							}
					}
			,'allowedHosts' => {
						'validate' => \&validateAllowedHosts
						,'PrefHead' => string('SETUP_FILTERRULE_HEAD')
						,'PrefDesc' => string('SETUP_FILTERRULE_DESC')
						,'PrefSize' => 'large'
					}

			}
		} #end of setup{'security'} hash
	,'performance' => {
		'title' => string('PERFORMANCE_SETTINGS')
		,'parent' => 'server'
		,'GroupOrder' => ['Default']
		,'Groups' => {
			'Default' => {
					'PrefOrder' => ['templatecache','useplaylistcache','animationLevel']
				}
			}
		,'Prefs' => {
			'templatecache' => {
						'validate' => \&validateTrueFalse
						,'options' => {
								'0' => string('SETUP_DONT_CACHE')
								,'1' => string('SETUP_CACHE')
								}
					}
			,'useplaylistcache' => {
						'validate' => \&validateTrueFalse
						,'options' => {
								'0' => string('SETUP_DONT_CACHE')
								,'1' => string('SETUP_CACHE')
								}
					}
			,'animationLevel' => {
						'validate' => \&validateInt
						,'validateArgs' => [0,3,1,1]
						,'options' => {
								'0' => string('SETUP_NO_ANIMATIONS')
								,'1' => string('SETUP_BRIEF_MESSAGES')
								,'2' => string('SETUP_SCREEN_WIPES')
								,'3' => string('SETUP_FULL_ANIMATION')
								}
					}
			}
		} #end of setup{'performance'} hash
	,'network' => {
		'title' => string('NETWORK_SETTINGS')
		,'parent' => 'server'
		,'GroupOrder' => ['Default','TCP_Params']
		,'Groups' => {
			'Default' => {
					'PrefOrder' => ['httpport','cliport','mDNSname','remotestreamtimeout']
				}
			,'TCP_Params' => {
					'PrefOrder' => ['tcpReadMaximum','tcpWriteMaximum','tcpConnectMaximum','udpChunkSize']
					,'PrefsInTable' => 1
					,'Suppress_PrefHead' => 1
					,'Suppress_PrefDesc' => 1
					,'Suppress_PrefLine' => 1
					,'Suppress_PrefSub' => 1
					,'GroupHead' => string('SETUP_GROUP_TCP_PARAMS')
					,'GroupDesc' => string('SETUP_GROUP_TCP_PARAMS_DESC')
					,'GroupLine' => 1
					,'GroupSub' => 1
				}
			}
		,'Prefs' => {
			'httpport'	=> {
						'validate' => \&validateInt
						,'validateArgs' => [1025,65535,undef,1]
						,'changeAddlText' => string('SETUP_NEW_VALUE')
									. '<blockquote><a target="_top" href="[EVAL]Slim::Web::HTTP::HomeURL()[/EVAL]">'
									. '[EVAL]Slim::Web::HTTP::HomeURL()[/EVAL]</a></blockquote>'
						,'onChange' => sub {
									my ($client,$changeref,$paramref,$pageref) = @_;
									$paramref->{'HomeURL'} = Slim::Web::HTTP::HomeURL();
								}
					}
			,'cliport'	=> {
						'validate' => \&validatePort
					}
			,'mDNSname'	=> {
							'validateArgs' => [] #will be set by preEval
							,'PrefSize' => 'medium'
					}
			,'remotestreamtimeout' => {
						'validate' => \&validateInt
						,'validateArgs' => [1,undef,1]
					}
			,'tcpReadMaximum' => {
						'validate' => \&validateInt
						,'validateArgs' => [1,undef,1]
					}
			,"tcpWriteMaximum" => {
						'validate' => \&validateInt
						,'validateArgs' => [1,undef,1]
					}
			,"tcpConnectMaximum" => {
						'validate' => \&validateInt
						,'validateArgs' => [1,undef,1]
					}
			,"udpChunkSize" => {
						'validate' => \&validateInt
						,'validateArgs' => [1,4096,1,1] #limit to 4096
					}
			}
		} #end of setup{'network'} hash
	,'advanced' => {
		'title' => string('ADDITIONAL_SERVER_SETTINGS')
		,'GroupOrder' => ['Default']
		,'Groups' => {
			'Default' => {
					'PrefOrder' => ['useinfocache','usetagdatabase']
				}
			}
		,'Prefs' => {
			'usetagdatabase' => {
						'validate' => \&validateTrueFalse
						,'options' => {
								'0' => string('SETUP_DONT_SAVE_TAG_INFO')
								,'1' => string('SETUP_SAVE_TAG_INFO')
							}
						}
			,'useinfocache' => {
						'validate' => \&validateTrueFalse
						,'options' => {
								'0' => string('SETUP_DONT_CACHE')
								,'1' => string('SETUP_CACHE')
								}
					}
			}
		} #end of setup{'advanced'} hash
	,'debug' => {
		'title' => string('DEBUGGING_SETTINGS')
		,'parent' => 'server'
		,'postChange' => sub {
					my ($client,$paramref,$pageref) = @_;
					no strict 'refs';
					foreach my $debugItem (@{$pageref->{'Groups'}{'Default'}{'PrefOrder'}}) {
						my $debugSet = "::" . $debugItem;
						if (!exists $paramref->{$debugItem}) {
							$paramref->{$debugItem} = $$debugSet;
						}
					}
				}
		,'GroupOrder' => ['Default']
		,'Groups' => {
			'Default' => {
					'PrefOrder' => [] # will be filled after hash is set up
					,'Suppress_PrefHead' => 1
#					,'Suppress_PrefDesc' => 1
					,'Suppress_PrefLine' => 1
					,'PrefsInTable' => 1
					,'GroupDesc' => string('SETUP_GROUP_DEBUG_DESC')

				}
			}
		,'Prefs' => {
			'd_' => { #template for the debug settings
					'validate' => \&validateTrueFalse
					,'inputTemplate' => 'setup_input_chk.html'
					,'dontSet' => 1
					,'currentValue' => sub {
								my ($client,$key,$ind) = @_;
								no strict 'refs';
								$key = '::' . $key;
								return $$key || 0;
							}
					,'onChange' => sub {
								my ($client,$changeref,$paramref,$pageref,$key,$ind) = @_;
								no strict 'refs';
								my $key2 = '::' . $key;
								$$key2 = $changeref->{$key}{'new'};
							}
				}
			}
		} #end of setup{'debug'} hash
	); #end of setup hash
	foreach my $key (sort keys %main:: ) {
		next unless $key =~ /^d_/;
		my %debugTemp = %{$setup{'debug'}{'Prefs'}{'d_'}};
		push @{$setup{'debug'}{'Groups'}{'Default'}{'PrefOrder'}},$key;
		$setup{'debug'}{'Prefs'}{$key} = \%debugTemp;
		$setup{'debug'}{'Prefs'}{$key}{'PrefChoose'} = $key;
		$setup{'debug'}{'Prefs'}{$key}{'changeIntro'} = $key;
	}
	if (scalar(keys %{Slim::Buttons::Plugins::installedPlugins()})) {
		push @{$setup{'server'}{'children'}},'plugins';
	}
}

sub initSetup {
	initSetupConfig();
	$setup{'server'}{'Prefs'}{'language'}{'options'} = {Slim::Utils::Strings::hash_of_languages()};
	$setup{'interface'}{'Prefs'}{'skin'}{'options'} = {skins(1)};
	$setup{'formatting'}{'Prefs'}{'longdateFormat'}{'validateArgs'} = [$setup{'formatting'}{'Prefs'}{'longdateFormat'}{'options'}];
	$setup{'formatting'}{'Prefs'}{'shortdateFormat'}{'validateArgs'} = [$setup{'formatting'}{'Prefs'}{'shortdateFormat'}{'options'}];
	$setup{'formatting'}{'Prefs'}{'timeFormat'}{'validateArgs'} = [$setup{'formatting'}{'Prefs'}{'timeFormat'}{'options'}];
	fillTitleFormatOptions();
}

sub fillTitleFormatOptions {
	$setup{'formatting'}{'Prefs'}{'titleFormatWeb'}{'options'} = {hash_of_titleFormats()};
	$setup{'player'}{'Prefs'}{'titleFormat'}{'options'} = {hash_of_titleFormats()};
	$setup{'player'}{'Prefs'}{'titleFormat'}{'validateArgs'} = [$setup{'player'}{'Prefs'}{'titleFormat'}{'options'}];
}

#returns a hash of title formats with the key being their array index and the value being the
#format string
sub hash_of_titleFormats {
	my %titleFormats;
	
	# hack around a race condition at startup
	if (!Slim::Utils::Prefs::getArrayMax('titleFormat')) {
		return;
	};
	
	$titleFormats{'-1'} = ' '; #used to delete a title format from the list
	my $tf = 0;
	foreach my $titleFormat (Slim::Utils::Prefs::getArray('titleFormat')) {
		$titleFormats{$tf++} = $titleFormat;
	}
	
	return %titleFormats;
}

#returns a hash reference to syncGroups available for a client
sub syncGroups {
	my $client = shift;
	my %clientlist = ();
	foreach my $eachclient (Slim::Player::Sync::canSyncWith($client)) {
		$clientlist{$eachclient->id()} =
		Slim::Player::Sync::syncname($eachclient, $client);
	}
	if (Slim::Player::Sync::isMaster($client)) {
		$clientlist{$client->id()} =
		Slim::Player::Sync::syncname($client, $client);
	}
	$clientlist{-1} = string('SETUP_NO_SYNCHRONIZATION');
	return \%clientlist;
}

sub setup_HTTP {
	my($client, $paramref) = @_;
	my $output = "";
	my $changed;
	my $rejected;
	if (!defined($paramref->{'page'})) {
		return '';
	}

	my %pagesetup = %{$setup{$paramref->{'page'}}};
	if (exists $pagesetup{'isClient'}) {
		$client = Slim::Player::Client::getClient($paramref->{'playerid'});
	} else {
		$client = 0;
	}

	if (defined $pagesetup{'preEval'}) {
		&{$pagesetup{'preEval'}}($client,$paramref,\%pagesetup);
	}
	($changed,$rejected) = setup_evaluation($client,$paramref,$pagesetup{'Prefs'});
	setup_changes_HTTP($changed,$paramref,$pagesetup{'Prefs'});
	setup_rejects_HTTP($rejected,$paramref,$pagesetup{'Prefs'});
	# accept any changes that were posted
	processChanges($client,$changed,$paramref,\%pagesetup);
	if (defined $pagesetup{'postChange'}) {
		&{$pagesetup{'postChange'}}($client,$paramref,\%pagesetup);
	}
	#fill the option lists
	#puts the list of options in the param 'preference_options'
	options_HTTP($client,$paramref,$pagesetup{'Prefs'});
	buildHTTP($client,$paramref,\%pagesetup);
	
	$output .= &Slim::Web::HTTP::filltemplatefile('setup.html', $paramref);
	return $output;
}

sub buildLinkList {
	my ($separator,$paramref,@pages) = @_;
	my $output = '';
	my $pagenum = 0;
	my %linkinfo;
	foreach my $page (@pages) {
		%linkinfo = ();
		#usePrefix is true for all but first item
		$linkinfo{'usePrefix'} = $pagenum;
		#useSuffix is true for all but last item
		$linkinfo{'useSuffix'} = !($pagenum == scalar(@pages));
		$pagenum++;
		$linkinfo{'paramlist'} = '?page=' . $page . '&player=' . (Slim::Web::HTTP::escape($paramref->{'player'})) . '&playerid=' . (Slim::Web::HTTP::escape($paramref->{'playerid'}));
		$linkinfo{'linktitle'} = $setup{$page}{'title'};
		if ($separator ne 'tree') {
			$linkinfo{'currpage'} = ($paramref->{'page'} eq $page);
		}
		$linkinfo{'linkpage'} = 'setup.html';
		$linkinfo{'separator'} = $separator;
		$linkinfo{'skinOverride'} = $$paramref{'skinOverride'};
		$output .= Slim::Web::HTTP::filltemplatefile('linklist.html',\%linkinfo);
	}
	return $output;
}

sub buildHTTP {
	my ($client,$paramref,$pageref) = @_;
	my ($page,@pages) = ();
	foreach my $group (@{$pageref->{'GroupOrder'}}) {
		if (!$group || !defined($pageref->{'Groups'}{$group})) {next;}
		my %groupparams = %{$pageref->{'Groups'}{$group}};
		$groupparams{'skinOverride'} = $$paramref{'skinOverride'};
		foreach my $pref (@{$pageref->{'Groups'}{$group}{'PrefOrder'}}) {
			if (!defined($pref) || !defined($pageref->{'Prefs'}{$pref})) { next; }
			my %prefparams = %{$pageref->{'Prefs'}{$pref}};
			$prefparams{'Suppress_PrefHead'} = $groupparams{'Suppress_PrefHead'};
			$prefparams{'Suppress_PrefDesc'} = $groupparams{'Suppress_PrefDesc'};
			$prefparams{'Suppress_PrefSub'} = $groupparams{'Suppress_PrefSub'};
			$prefparams{'Suppress_PrefLine'} = $groupparams{'Suppress_PrefLine'};
			$prefparams{'PrefsInTable'} = $groupparams{'PrefsInTable'};
			$prefparams{'skinOverride'} = $groupparams{'skinOverride'};
			
			if (!exists $prefparams{'PrefHead'}) {
				$prefparams{'PrefHead'} = Slim::Utils::Strings::stringExists('SETUP_' . uc($pref)) ? string('SETUP_' . uc($pref)) : $pref;
			}
			if (!exists $prefparams{'PrefDesc'} && Slim::Utils::Strings::stringExists('SETUP_' . uc($pref) . '_DESC')) {
				$prefparams{'PrefDesc'} = string('SETUP_' . uc($pref) . '_DESC');
			}
			if (!exists $prefparams{'PrefChoose'} && Slim::Utils::Strings::stringExists('SETUP_' . uc($pref) . '_CHOOSE')) {
				$prefparams{'PrefChoose'} = string('SETUP_' . uc($pref) . '_CHOOSE');
			}
			if (!exists $prefparams{'inputTemplate'}) {
				$prefparams{'inputTemplate'} = (exists $prefparams{'options'}) ? 'setup_input_sel.html' : 'setup_input_txt.html';
			}
			if (!exists $prefparams{'ChangeButton'}) {
				$prefparams{'ChangeButton'} = string('CHANGE');
			}
			$prefparams{'page'} = $paramref->{'page'};

			my $arrayMax = 0;
			my $arrayCurrent;
			if (exists($pageref->{'Prefs'}{$pref}{'isArray'})) {
				if (defined($pageref->{'Prefs'}{$pref}{'arrayMax'})) {
					$arrayMax = $pageref->{'Prefs'}{$pref}{'arrayMax'};
				} else {
					$arrayMax = ($client) ? Slim::Utils::Prefs::clientGetArrayMax($client,$pref) : Slim::Utils::Prefs::getArrayMax($pref);
				}
				if (defined($pageref->{'Prefs'}{$pref}{'arrayCurrentPref'})) {
					$prefparams{'PrefArrayCurrName'} = $pageref->{'Prefs'}{$pref}{'arrayCurrentPref'};
					$arrayCurrent = ($client) ? Slim::Utils::Prefs::clientGet($client,$pageref->{'Prefs'}{$pref}{'arrayCurrentPref'})
								: Slim::Utils::Prefs::get($pageref->{'Prefs'}{$pref}{'arrayCurrentPref'});
				}
				if (defined($pageref->{'Prefs'}{$pref}{'arrayAddExtra'})) {
					my $adval = defined($pageref->{'Prefs'}{$pref}{'arrayDeleteValue'}) ? $pageref->{'Prefs'}{$pref}{'arrayDeleteValue'} : '';
					for (my $i = $arrayMax + 1; $i <= $arrayMax + $pageref->{'Prefs'}{$pref}{'arrayAddExtra'}; $i++) {
						$paramref->{$pref . $i} = $adval;
					}
					$arrayMax += $pageref->{'Prefs'}{$pref}{'arrayAddExtra'};
				}
			}
			for (my $i=0; $i <= $arrayMax; $i++) {
				my $pref2 = $pref . (exists($pageref->{'Prefs'}{$pref}{'isArray'}) ? $i : '');
				$prefparams{'PrefName'} = $pref2;
				$prefparams{'PrefNameRoot'} = $pref;
				$prefparams{'PrefIndex'} = $i;
				if (!exists($paramref->{$pref2}) && !exists($pageref->{'Prefs'}{$pref}{'dontSet'})) {
					if (!exists($pageref->{'Prefs'}{$pref}{'isArray'})) {
						$paramref->{$pref2} = ($client) ? Slim::Utils::Prefs::clientGet($client,$pref2) : Slim::Utils::Prefs::get($pref2);
					} else {
						$paramref->{$pref2} = ($client) ? Slim::Utils::Prefs::clientGetInd($client,$pref,$i) : Slim::Utils::Prefs::getInd($pref,$i);
					}
				}
				$prefparams{'PrefValue'} = $paramref->{$pref2};
				if (exists $pageref->{'Prefs'}{$pref}{'externalValue'}) {
					$prefparams{'PrefExtValue'} = &{$pageref->{'Prefs'}{$pref}{'externalValue'}}($client,$paramref->{$pref2},$pref2);
				} else {
					$prefparams{'PrefExtValue'} = $paramref->{$pref2};
				}
				$prefparams{'PrefOptions'} = $paramref->{$pref2 . '_options'};
				if (exists($pageref->{'Prefs'}{$pref}{'isArray'})) {
					$prefparams{'PrefSelected'} = (defined($arrayCurrent) && ($arrayCurrent eq $i)) ? 'checked' : undef;
				} else {
					$prefparams{'PrefSelected'} = $paramref->{$pref2} ? 'checked' : undef;
				}
				$prefparams{'PrefInput'} = Slim::Web::HTTP::filltemplatefile($prefparams{'inputTemplate'},\%prefparams);
				$groupparams{'PrefList'} .= Slim::Web::HTTP::filltemplatefile('setup_pref.html',\%prefparams);
			}
		}
		if (!exists $groupparams{'ChangeButton'}) {
			$groupparams{'ChangeButton'} = string('CHANGE');
		}

		$paramref->{'GroupList'} .= Slim::Web::HTTP::filltemplatefile('setup_group.html',\%groupparams);
	}
	#set up pagetitle
	$paramref->{'pagetitle'} = $pageref->{'title'};
	#set up link tree
	$page = $paramref->{'page'};
	@pages = ();
	while (defined $page) {
		unshift @pages,$page;
		$page = $setup{$page}{'parent'};
	}
	$paramref->{'linktree'} = buildLinkList('tree',$paramref,@pages);;
	
	#set up sibling bar
	if (defined $pageref->{'parent'} && defined $setup{$pageref->{'parent'}}{'children'}) {
		@pages = @{$setup{$pageref->{'parent'}}{'children'}};
		if (scalar(@pages) > 1) {
			$paramref->{'siblings'} = buildLinkList('tab',$paramref,@pages);
		}
	}
	
	#set up children bar and single child link
	if (defined $pageref->{'children'}) {
		@pages = @{$pageref->{'children'}};
		$paramref->{'children'} = buildLinkList('list',$paramref,@pages);
		my %linkinfo = ('linkpage' => 'setup.html'
				,'paramlist' => '?page=' . $pageref->{'children'}[0] . '&player=' . Slim::Web::HTTP::escape($paramref->{'player'}) . '&playerid=' . Slim::Web::HTTP::escape($paramref->{'playerid'})
				,'skinOverride' => $$paramref{'skinOverride'}
				);
		if (defined $pageref->{'singleChildLinkText'}) {
			$linkinfo{'linktitle'} = $pageref->{'singleChildLinkText'};
		} else {
			$linkinfo{'linktitle'} = $setup{$pageref->{'children'}[0]}{'title'};
		}
		$paramref->{'singleChildLink'} = Slim::Web::HTTP::filltemplatefile('linklist.html',\%linkinfo);
		
	}

}

sub processChanges {
	my ($client,$changeref,$paramref,$pageref) = @_;
	foreach my $key (keys %{$changeref}) {
		$key =~ /(.+?)(\d*)$/;
		my $keyA = $1;
		my $keyI = $2;
		if (exists $pageref->{'Prefs'}{$keyA}{'onChange'}) {
			&{$pageref->{'Prefs'}{$keyA}{'onChange'}}($client,$changeref,$paramref,$pageref,$keyA,$keyI);
		}
	}
}

sub processArrayChange {
	my ($client,$array,$paramref,$pageref) = @_;
	my $arrayMax = ($client) ? Slim::Utils::Prefs::clientGetArrayMax($client,$array) : Slim::Utils::Prefs::getArrayMax($array);
	if ($pageref->{'Prefs'}{$array}{'arrayDeleteNull'}) {
		my $acval;
		if (defined($pageref->{'Prefs'}{$array}{'arrayCurrentPref'})) {
			$acval = ($client) ? Slim::Utils::Prefs::clientGet($client,$pageref->{'Prefs'}{$array}{'arrayCurrentPref'})
						: Slim::Utils::Prefs::get($pageref->{'Prefs'}{$array}{'arrayCurrentPref'});
		}
		my $adval = defined($pageref->{'Prefs'}{$array}{'arrayDeleteValue'}) ? $pageref->{'Prefs'}{$array}{'arrayDeleteValue'} : '';
		for (my $i = $arrayMax;$i >= 0;$i--) {
			my $aval = ($client) ? Slim::Utils::Prefs::clientGet($client,$array,$i) : Slim::Utils::Prefs::getInd($array,$i);
			if (!defined $aval || $aval eq '' || $aval eq $adval) {
				if ($client) {
					Slim::Utils::Prefs::clientDelete($client,$array,$i);
				} else {
					Slim::Utils::Prefs::delete($array,$i);
				}
				if (defined $acval && $acval >= $i) {
					$acval--;
				}
			}
		}
		if (defined($pageref->{'Prefs'}{$array}{'arrayCurrentPref'})) {
			if ($client) {
				Slim::Utils::Prefs::clientSet($client,$pageref->{'Prefs'}{$array}{'arrayCurrentPref'},$acval);
			} else {
				Slim::Utils::Prefs::set($pageref->{'Prefs'}{$array}{'arrayCurrentPref'},$acval);
			}
		}
		$arrayMax = ($client) ? Slim::Utils::Prefs::clientGetArrayMax($client,$array) : Slim::Utils::Prefs::getArrayMax($array);
		if ($arrayMax < 0 && defined($pageref->{'Prefs'}{$array}{'arrayBasicValue'})) {
			#all the array entries were deleted, so set one up
			if ($client) {
				Slim::Utils::Prefs::clientSet($client,$array,$pageref->{'Prefs'}{$array}{'arrayBasicValue'},0);
			} else {
				Slim::Utils::Prefs::set($array,$pageref->{'Prefs'}{$array}{'arrayBasicValue'},0);
			}
			if (defined($pageref->{'Prefs'}{$array}{'arrayCurrentPref'})) {
				if ($client) {
					Slim::Utils::Prefs::clientSet($client,$pageref->{'Prefs'}{$array}{'arrayCurrentPref'},0);
				} else {
					Slim::Utils::Prefs::set($pageref->{'Prefs'}{$array}{'arrayCurrentPref'},0);
				}
			}
			$arrayMax = 0;
		}
		#update the params hash, since the array entries may have shifted around some
		for (my $i = 0;$i <= $arrayMax;$i++) {
			$paramref->{$array . $i} = ($client) ? Slim::Utils::Prefs::clientGet($client,$array,$i) : Slim::Utils::Prefs::getInd($array,$i);
		}
		#further update params hash to clear shifted values
		my $i = $arrayMax + 1;
		while (exists $paramref->{$array . $i}) {
			$paramref->{$array . $i} = $adval;
			$i++;
		}
	}
}

sub removeExtraArrayEntries {
	my ($client,$array,$paramref,$pageref) = @_;
	if (!defined($pageref->{'Prefs'}{$array}{'arrayAddExtra'})) {
		return;
	}
	my $arrayMax = ($client) ? Slim::Utils::Prefs::clientGetArrayMax($client,$array) : Slim::Utils::Prefs::getArrayMax($array);
	my $adval = defined($pageref->{'Prefs'}{$array}{'arrayDeleteValue'}) ? $pageref->{'Prefs'}{$array}{'arrayDeleteValue'} : '';
	for (my $i = $arrayMax + $pageref->{'Prefs'}{$array}{'arrayAddExtra'};$i > $arrayMax;$i--) {
		if (exists $paramref->{$array . $i} && (!defined($paramref->{$array . $i}) || $paramref->{$array . $i} eq '' || $paramref->{$array . $i} eq $adval)) {
			delete $paramref->{$array . $i};
		}
	}
}

sub skins {
	my $forUI = shift;
	
	my %skinlist = ();

	foreach my $templatedir (Slim::Web::HTTP::HTMLTemplateDirs()) {
		foreach my $dir (Slim::Utils::Misc::readDirectory($templatedir)) {
			# reject CVS and html directories as skins
			next if $dir =~ /^(?:cvs|html)$/i;
			next if $forUI && $dir eq 'xml';
			next if !-d catdir($templatedir, $dir);
			
			$::d_http && msg(" skin entry: $dir\n");
			
			if ($dir eq Slim::Web::HTTP::defaultSkin()) {
				$skinlist{$dir} = string('DEFAULT_SKIN');
			} elsif ($dir eq Slim::Web::HTTP::baseSkin()) {
				$skinlist{$dir} = string('BASE_SKIN');
			} else {
				$skinlist{$dir} = Slim::Web::HTTP::unescape($dir);
			}
		}
	}
	return %skinlist;
}

sub setup_evaluation {
	my ($client, $paramref, $settingsref) = @_;
	my %changes = ();
	my %rejects = ();
	foreach my $key (keys %$settingsref) {
		my $arrayMax = 0;
		if (exists($settingsref->{$key}{'isArray'})) {
			if (defined($settingsref->{$key}{'arrayMax'})) {
				$arrayMax = $settingsref->{$key}{'arrayMax'};
			} else {
				$arrayMax = ($client) ? Slim::Utils::Prefs::clientGetArrayMax($client,$key) : Slim::Utils::Prefs::getArrayMax($key);
			}
			if (exists($settingsref->{$key}{'arrayAddExtra'})) {
				my $adval = defined($settingsref->{$key}{'arrayDeleteValue'}) ? $settingsref->{$key}{'arrayDeleteValue'} : '';
				for (my $i=$arrayMax + $settingsref->{$key}{'arrayAddExtra'}; $i > $arrayMax; $i--) {
					if (exists $paramref->{$key . $i} && (defined($paramref->{$key . $i}) || $paramref->{$key . $i} ne '' || $paramref->{$key . $i} ne $adval)) {
						$arrayMax = $i;
						last;
					}
				}
			}
		}

		for (my $i=0; $i <= $arrayMax; $i++) {
			my ($key2,$currVal);
			if (exists($settingsref->{$key}{'isArray'})) {
				$key2 = $key . $i;
				if (exists($settingsref->{$key}{'currentValue'})) {
					$currVal = &{$settingsref->{$key}{'currentValue'}}($client,$key,$i);
				} else {
					$currVal = ($client) ? Slim::Utils::Prefs::clientGet($client,$key,$i) : Slim::Utils::Prefs::getInd($key,$i);
				}
			} else {
				$key2 = $key;
				if (exists($settingsref->{$key}{'currentValue'})) {
					$currVal = &{$settingsref->{$key}{'currentValue'}}($client,$key);
				} else {
					$currVal = ($client) ? Slim::Utils::Prefs::clientGet($client,$key) : Slim::Utils::Prefs::get($key);
				}
			}
			if (defined($paramref->{$key2})) {
				my ($pvalue, $errmsg);
				if (exists $settingsref->{$key}{'validate'}) {
					if (exists $settingsref->{$key}{'validateArgs'}) {
						($pvalue, $errmsg) = &{$settingsref->{$key}{'validate'}}($paramref->{$key2},@{$settingsref->{$key}{'validateArgs'}});
					} else {
						($pvalue, $errmsg) = &{$settingsref->{$key}{'validate'}}($paramref->{$key2});
					}
				} else { #accept everything
					$pvalue = $paramref->{$key2};
				}
				if (defined($pvalue)) {
					# the following if is true if the current setting is different
					# from the setting in the param hash
					if (!(defined($currVal) && $currVal eq $pvalue)) {
						if ($client) {
							$changes{$key2}{'old'} = $currVal;
							if (!exists $settingsref->{$key}{'dontSet'}) {
								Slim::Utils::Prefs::clientSet($client,$key2,$pvalue);
							}
						} else {
							$changes{$key2}{'old'} = $currVal;
							if (!exists $settingsref->{$key}{'dontSet'}) {
								Slim::Utils::Prefs::set($key2,$pvalue);
							}
						}
						$changes{$key2}{'new'} = $pvalue;
						$currVal = $pvalue;
					}
				} else {
					$rejects{$key2} = $paramref->{$key2};
				}
			}
			if (!exists $settingsref->{$key}{'dontSet'}) {
				$paramref->{$key2} = $currVal;
			}
		}
	}
	return \%changes,\%rejects;
}

sub setup_changes_HTTP {
	my $changeref = shift;
	my $paramref = shift;
	my $settingsref = shift;
	foreach my $key (keys %{$changeref}) {
		$key =~ /(.+?)(\d*)$/;
		my $keyA = $1;
		my $keyI = $2;
		my $changemsg = undef;
		my $changedval = undef;
		if (exists $settingsref->{$keyA}{'noWarning'}) {
			next;
		}
		if (exists $settingsref->{$keyA}{'changeIntro'}) {
			$changemsg = sprintf($settingsref->{$keyA}{'changeIntro'},$keyI);
		} elsif (Slim::Utils::Strings::stringExists('SETUP_' . uc($keyA) . '_OK')) {
			$changemsg = string('SETUP_' . uc($keyA) . '_OK');
		} else {
			$changemsg = (string('SETUP_' . uc($keyA)) || $keyA) 
				. ' ' . $keyI . ':';
		}
		$changemsg .= '<p>';
		#use external value from 'options' hash
		if (exists $settingsref->{$keyA}{'changeoptions'}) {
			if ($settingsref->{$keyA}{'changeoptions'}) {
				$changedval = $settingsref->{$keyA}{'changeoptions'}{$changeref->{$key}{'new'}};
			}
		} elsif (exists $settingsref->{$keyA}{'options'}) {
			$changedval = $settingsref->{$keyA}{'options'}{$changeref->{$key}{'new'}};
		} elsif (exists $settingsref->{$keyA}{'externalValue'}) {
			#todo get the current client from the $paramref hash, not currently needed
			#but would be if there was an 'externalValue' function that actually used
			#the $client parameter
			$changedval = &{$settingsref->{$keyA}{'externalValue'}}(undef,$changeref->{$key},$key);
		} else {
			$changedval = $changeref->{$key}{'new'};
		}
		if (exists $settingsref->{$keyA}{'changeMsg'}) {
			$changemsg .= $settingsref->{$keyA}{'changeMsg'};
		} else {
			$changemsg .= '%s';
		}
		$changemsg .= '</p>';
		if (exists $settingsref->{$keyA}{'changeAddlText'}) {
			$changemsg .= $settingsref->{$keyA}{'changeAddlText'};
		}
		#force eval on the filltemplate call
		if (defined($changedval) && $changemsg) {
			$paramref->{'warning'} .= sprintf(Slim::Web::HTTP::filltemplate($changemsg,undef,1),$changedval);
		}
	}
}

sub setup_rejects_HTTP {
	my $rejectref = shift;
	my $paramref = shift;
	my $settingsref = shift;
	foreach my $key (keys %{$rejectref}) {
		$key =~ /(.+?)(\d*)$/;
		my $keyA = $1;
		my $keyI = $2;
		my $rejectmsg;
		if (exists $settingsref->{$keyA}{'rejectIntro'}) {
			$rejectmsg = sprintf($settingsref->{$keyA}{'rejectIntro'},$keyI);
		} else {
			$rejectmsg = string('SETUP_NEW_VALUE') . ' ' . 
						(string('SETUP_' . uc($keyA)) || $keyA) . ' ' . 
						$keyI . string("SETUP_REJECTED") . ':';
		}
		$rejectmsg .= ' <blockquote> ';
		if (exists $settingsref->{$keyA}{'rejectMsg'}) {
			$rejectmsg .= $settingsref->{$keyA}{'rejectMsg'};
		} else {
			$rejectmsg .= string('SETUP_BAD_VALUE');
		}
		$rejectmsg .= '</blockquote><p>';
		if (exists $settingsref->{$keyA}{'rejectAddlText'}) {
			$rejectmsg .= $settingsref->{$keyA}{'rejectAddlText'};
		}
		#force eval on the filltemplate call
		$paramref->{'warning'} .= sprintf(Slim::Web::HTTP::filltemplate($rejectmsg,undef,1),$rejectref->{$key});
	}
}

sub options_HTTP {
	my ($client, $paramref, $settingsref) = @_;

	foreach my $key (keys %$settingsref) {
		my $arrayMax = 0;
		if (exists($settingsref->{$key}{'isArray'})) {
			$arrayMax = ($client) ? Slim::Utils::Prefs::clientGetArrayMax($client,$key) : Slim::Utils::Prefs::getArrayMax($key);
			if (!defined $arrayMax) { $arrayMax = 0; }
			if (exists($settingsref->{$key}{'arrayAddExtra'})) {
				$arrayMax += $settingsref->{$key}{'arrayAddExtra'};
			}
		}
		for (my $i=0; $i <= $arrayMax; $i++) {
			my $key2 = $key . (exists($settingsref->{$key}{'isArray'}) ? $i : '');
			if (exists $settingsref->{$key}{'options'}) {
				if ($settingsref->{$key}{'inputTemplate'} && $settingsref->{$key}{'inputTemplate'} eq 'setup_input_radio.html') {
					$paramref->{$key2 . '_options'} = fillRadioOptions($paramref->{$key2},$settingsref->{$key}{'options'},$key);
				} else {
					$paramref->{$key2 . '_options'} = fillOptions($paramref->{$key2},$settingsref->{$key}{'options'});
				}
			}
		}
	}
}

sub fillOptions {
	#pass in the selected value and a hash of value => text pairs to get the option list filled
	#with the correct option selected.  Since the text portion can be a template (for stringification)
	#perform a filltemplate on the completed list
	my ($selected,$optionref) = @_;
	my $optionlist = '';
	foreach my $curroption (sort keys %{$optionref}) {
		$optionlist .= "<option " . ((defined($selected) && ($curroption eq $selected)) ? "selected " : ""). qq(value="${curroption}">$optionref->{$curroption}</option>)
	}
	return $optionlist;
}

sub fillRadioOptions {
	#pass in the selected value and a hash of value => text pairs to get the option list filled
	#with the correct option selected.  Since the text portion can be a template (for stringification)
	#perform a filltemplate on the completed list
	my ($selected,$optionref,$option) = @_;
	my $optionlist = '';
	foreach my $curroption (sort {${$optionref}{$a} cmp ${$optionref}{$b}} keys %{$optionref}) {
		$optionlist .= "<p><input type=\"radio\" " . 
						((defined($selected) && ($curroption eq $selected)) ? "checked " : ""). 
						qq(value="${curroption}" name="$option">$optionref->{$curroption}</p>)
	}
	return $optionlist;
}

######################################################################
# Setup Hash Manipulation Functions
######################################################################
# Adds the preference to the PrefOrder array of the supplied group at the
# supplied position (or at the end if no position supplied)
sub addPrefToGroup {
	my ($category,$groupname,$prefname,$position) = @_;
	unless (exists $setup{$category} && exists $setup{$category}{'Groups'}{$groupname}) {
		# either the category or the group within the category is invalid
		warn "Group $groupname in category $category does not exist\n";
		return;
	}
	if (!defined $position || $position > scalar(@{$setup{$category}{'Groups'}{$groupname}{'PrefOrder'}})) {
		$position = scalar(@{$setup{$category}{'Groups'}{$groupname}{'PrefOrder'}});
	}
	splice(@{$setup{$category}{'Groups'}{$groupname}{'PrefOrder'}},$position,0,$prefname);
	return;
}
# Removes the preference from the PrefOrder array of the supplied group
# in the supplied category
sub removePrefFromGroup {
	my ($category,$groupname,$prefname,$noWarn) = @_;
	# Find $prefname in $setup{$category}{'Groups'}{$groupname}{'PrefOrder'} array
	unless (exists $setup{$category} && exists $setup{$category}{'Groups'}{$groupname}) {
		# either the category or the group within the category is invalid
		warn "Group $groupname in category $category does not exist\n";
		return;
	}
	my $i = 0;
	for my $currpref (@{$setup{$category}{'Groups'}{$groupname}{'PrefOrder'}}) {
		if ($currpref eq $prefname) {
			splice (@{$setup{$category}{'Groups'}{$groupname}{'PrefOrder'}},$i,1);
			$i = -1; # indicates that a preference was removed
			last;
		}
		$i++;
	}
	if ($i > 0 && !$noWarn) {
		warn "Preference $prefname not found in group $groupname in category $category\n";
	}
	return;
}
# Adds the preference to the category.  A reference to a hash containing the
# preference data must be supplied.
sub addPref {
	my ($category,$prefname,$prefref,$groupname,$position) = @_;
	unless (exists $setup{$category}) {
		warn "Category $category does not exist\n";
		return;
	}
	$setup{$category}{'Prefs'}{$prefname} = $prefref;
	if (defined $groupname) {
		addPrefToGroup($category,$groupname,$prefname,$position);
	}
	return;
}
# Removes the preference from the supplied category, optionally removes
# all references to the preference from the PrefOrder arrays of the groups
# within the category
sub delPref {
	my ($category,$prefname,$andGroupRefs) = @_;
	
	unless (exists $setup{$category}) {
		warn "Category $category does not exist\n";
		return;
	}
	delete $setup{$category}{'Prefs'}{$prefname};
	if ($andGroupRefs) {
		for my $group (@{$setup{$category}{'GroupOrder'}}) {
			removePrefFromGroup($category,$group,$prefname,1);
		}
	}
	return;
}
# Adds a group to the supplied category.  A reference to a hash containing the
# group data must be supplied.  If a reference to a hash of preferences is supplied,
# they will also be added to the category.
sub addGroup {
	my ($category,$groupname,$groupref,$position,$prefsref) = @_;
	unless (exists $setup{$category}) {
		warn "Category $category does not exist\n";
		return;
	}
	unless (defined $groupname && defined $groupref) {
		warn "No group information supplied!\n";
		return;
	}
	$setup{$category}{'Groups'}{$groupname} = $groupref;
	my $found = 0;
	foreach (@{$setup{$category}{'GroupOrder'}}) {
		$found = 1,last if $_ eq $groupname;
	}
	if (!$found) {
		if (!defined $position || $position > scalar(@{$setup{$category}{'GroupOrder'}})) {
			$position = scalar(@{$setup{$category}{'GroupOrder'}});
		}
		splice(@{$setup{$category}{'GroupOrder'}},$position,0,$groupname);
	}
	if (defined $prefsref) {
		my ($pref,$prefref);
		while (($pref,$prefref) = each %{$prefsref}) {
			$setup{$category}{'Prefs'}{$pref} = $prefref;
			$::d_prefs && msg("Adding $pref to setup hash\n");
		}
	}
	return;
}
# Deletes a group from a category and optionally the associated preferences
sub delGroup {
	my ($category,$groupname,$andPrefs) = @_;
	unless (exists $setup{$category}) {
		warn "Category $category does not exist\n";
		return;
	}
	my @preflist;
	if (exists $setup{$category}{'Groups'}{$groupname} && $andPrefs) {
		#hold on to preferences for later deletion
		@preflist = @{$setup{$category}{'Groups'}{$groupname}{'PrefOrder'}};
	}
	#remove from Groups hash
	delete $setup{$category}{'Groups'}{$groupname};
	#remove from GroupOrder array
	my $i=0;
	for my $currgroup (@{$setup{$category}{'GroupOrder'}}) {
		if ($currgroup eq $groupname) {
			splice (@{$setup{$category}{'GroupOrder'}},$i,1);
			last;
		}
		$i++;
	}
	#delete associated preferences if requested
	if ($andPrefs) {
		for my $pref (@preflist) {
			delPref($category,$pref);
		}
	}
	return;
}
######################################################################
# Validation Functions
######################################################################
sub validateAcceptAll {
	my $val = shift;
	return $val;
}

sub validateTrueFalse {
	# use the perl idea of true and false.
	my $val = shift;
	if ($val) {
		return 1;
	} else {
		return 0;
	}
}

sub validateInt {
	my ($val,$low,$high,$setLow,$setHigh) = @_;
	if ($val !~ /^-?\d+$/) { #not an integer
		return undef;
	} elsif (defined($low) && $val < $low) { # too low, equal to $low is acceptable
		if ($setLow) {
			return $low;
		} else {
			return undef;
		}
	} elsif (defined($high) && $val > $high) { # too high, equal to $high is acceptable
		if ($setHigh) {
			return $high;
		} else {
			return undef;
		}
	}
	return $val;
}

sub validatePort {
	my $val = shift;

	if ($val !~ /^-?\d+$/) { #not an integer
		return undef;
	}
	if ($val == 0) {
		return $val;
	}
	if ($val < 1024) {
		return undef;
	}
	if ($val > 65535) {
		return undef;
	}
	return $val;

}
sub validateNumber {
	my ($val,$low,$high,$setLow,$setHigh) = @_;
	if ($val !~ /^-?\d+\.?\d*$/) { # this doesn't recognize scientific notation
		return undef;
	} elsif (defined($low) && $val < $low) { # too low, equal to $low is acceptable
		if ($setLow) {
			return $low;
		} else {
			return undef;
		}
	} elsif (defined($high) && $val > $high) { # too high, equal to $high is acceptable
		if ($setHigh) {
			return $high;
		} else {
			return undef;
		}
	}
	return $val;
}

sub validateInList {
	my ($val,@valList) = @_;
	my $inList = 0;
	foreach my $valFromList (@valList) {
		$inList = ($valFromList eq $val);
		last if $inList;
	}
	if ($inList) {
		return $val;
	} else {
		return undef;
	}
}

#determines if the value is one of the keys of the supplied hash
#the hash is supplied in the form of a reference either to a hash, or to code which returns a hash
sub validateInHash {
	my $val = shift;
	my $ref = shift;
	my $codereturnsref = shift; #should be set to 1 if $ref is to code that returns a hash reference

	my %hash = ();
	if (ref($ref)) {
		if (ref($ref) eq 'HASH') {
			%hash = %{$ref}
		} elsif (ref($ref) eq 'CODE') {
			if ($codereturnsref) {
				%hash = %{&{$ref}};
			} else {
				%hash = &{$ref};
			}
		}
	}
	if (exists $hash{$val}) {
		return $val;
	} else {
		return undef;
	}
}

sub validateIsDir {
	my $val = shift;
	my $allowEmpty = shift;
	if (-d $val) {
		$val =~ s|[/\\]$||;
		return $val;
	} elsif ($allowEmpty && defined($val) && $val eq '') {
		return $val;
	} else  {
		return (undef, "SETUP_BAD_DIRECTORY") ;
	}
}

sub validateIsMP3Dir {
	my $val = shift;
	my $allowEmpty = shift;
	if (Slim::Music::iTunes::useiTunesLibrary()) {
		return $val;
	} elsif (-d $val) {
		$val =~ s|[/\\]$||;
		return $val;
	} elsif ($allowEmpty && defined($val) && $val eq '') {
		return $val;
	} else  {
		return (undef, "SETUP_BAD_DIRECTORY") ;
	}
}

sub validateITunes {
	my $val = shift;
	
	if ($val == 1) {
	} elsif ($val == 0) {
		Slim::Utils::Prefs::set('mp3dir', '');
	} else {
		$val = undef;
	}
	
	return $val;
}

sub validateHasText {
	my $val = shift; # value to validate
	my $defaultText = shift; #value to use if nothing in the $val param

	if (defined($val) && $val ne '') {
		return $val;
	} else {
		return $defaultText;
	}
}

sub validatePassword {
	my $val = shift;
	my $currentPassword = Slim::Utils::Prefs::get('password');
	if (defined($val) && $val ne '' && $val ne $currentPassword) {
		srand (time());
		my $randletter = "(int (rand (26)) + (int (rand (1) + .5) % 2 ? 65 : 97))";
		my $salt = sprintf ("%c%c", eval $randletter, eval $randletter);
		return crypt($val, $salt);
	} else {
		return $currentPassword;
	}
}

#TODO make this actually check to see if the format is valid
sub validateFormat {
	my $val = shift;
	if (!defined($val)) {
		return undef;
	} elsif ($val eq '') {
		return $val;
	} else {
		return $val;
	}
}

#Verify allowed hosts is in somewhat proper format, always prepend 127.0.0.1 if not there
sub validateAllowedHosts {
	my $val = shift;
	$val =~ s/\s+//g;
	if (!defined($val) || $val eq '') {
	    return join(',', Slim::Utils::Misc::hostaddr());
	} else {
 		return $val;
 	}
 }

1;

# Local Variables:
# tab-width:4
# indent-tabs-mode:t
# End:
