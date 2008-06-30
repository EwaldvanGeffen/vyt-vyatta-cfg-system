#!/usr/bin/perl
#
# Module: vyatta-vrrp-state.pl
# 
# **** License ****
# This program is free software; you can redistribute it and/or modify
# it under the terms of the GNU General Public License version 2 as
# published by the Free Software Foundation.
# 
# This program is distributed in the hope that it will be useful, but
# WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the GNU
# General Public License for more details.
#
# This code was originally developed by Vyatta, Inc.
# Portions created by Vyatta are Copyright (C) 2007 Vyatta, Inc.
# All Rights Reserved.
# 
# Author: Stig Thormodsrud
# Date: October 2007
# Description: Script called on vrrp master state transition
# 
# **** End License ****
#

use lib "/opt/vyatta/share/perl5/";
use VyattaKeepalived;
use POSIX;

use strict;
use warnings;


sub vrrp_state_log {
    my ($state, $intf, $group) = @_;

    my $timestamp = strftime("%Y%m%d-%H:%M.%S", localtime);    
    my $file = VyattaKeepalived::get_state_file($intf, $group);
    my $time = time();
    my $line = "$time $intf $group $state $timestamp";
    open my $fh, ">", $file;
    print $fh $line;
    close $fh;
}

my $vrrp_state = $ARGV[0];
my $vrrp_intf  = $ARGV[1];
my $vrrp_group = $ARGV[2];
my $vrrp_transitionscript = $ARGV[3];
my @vrrp_vips;
foreach my $arg (4 .. $#ARGV) {
    push @vrrp_vips, $ARGV[$arg];
}

my $sfile = VyattaKeepalived::get_state_file($vrrp_intf, $vrrp_group);
my ($old_time, $old_intf, $old_group, $old_state, $old_ltime) = 
    VyattaKeepalived::vrrp_state_parse($sfile);
if (defined $old_state and $vrrp_state eq $old_state) {
    # 
    # restarts call the transition script even if it really hasn't
    # changed.
    #
    VyattaKeepalived::vrrp_log("$vrrp_intf $vrrp_group same - $vrrp_state");
    exit 0;
}

VyattaKeepalived::vrrp_log("$vrrp_intf $vrrp_group transition to $vrrp_state");
vrrp_state_log($vrrp_state, $vrrp_intf, $vrrp_group);
if ($vrrp_state eq "backup") {
    VyattaKeepalived::snoop_for_master($vrrp_intf, $vrrp_group, $vrrp_vips[0], 
				       60);
} elsif ($vrrp_state eq "master") {
    #
    # keepalived will send gratuitous arp requests on master transition
    # but some hosts do not update their arp cache for gratuitous arp 
    # requests.  Some of those host do respond to gratuitous arp replies
    # so here we will send 5 gratuitous arp replies also.
    #
    foreach my $vip (@vrrp_vips) {
	system("/usr/bin/arping -A -c5 -I $vrrp_intf $vip");
    }

    #
    # remove the old master file since we are now master
    #
    my $mfile = VyattaKeepalived::get_master_file($vrrp_intf, $vrrp_group);
    system("rm -f $mfile");
}

if (!($vrrp_transitionscript eq "null")){
    exec("$vrrp_transitionscript");
}

exit 0;

# end of file




