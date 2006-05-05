
# Copyright 2001-2006 Eric Vaandering, Lynn Garren, Adam Bryant

#    This file is part of DocDB.

#    DocDB is free software; you can redistribute it and/or modify
#    it under the terms of version 2 of the GNU General Public License 
#    as published by the Free Software Foundation.

#    DocDB is distributed in the hope that it will be useful,
#    but WITHOUT ANY WARRANTY; without even the implied warranty of
#    MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
#    GNU General Public License for more details.

#    You should have received a copy of the GNU General Public License
#    along with DocDB; if not, write to the Free Software
#    Foundation, Inc., 59 Temple Place, Suite 330, Boston, MA  02111-1307  USA

sub PrintGroupParents ($) {
  my ($GroupID) = @_;

  my @HierarchyIDs = keys %GroupsHierarchy;
  my @Parents = ();
  
  foreach my $HierarchyID (@HierarchyIDs) {
    if ($GroupID == $GroupsHierarchy{$HierarchyID}{Child}) {
      my $ParentID = $GroupsHierarchy{$HierarchyID}{Parent};
      push @Parents,$SecurityGroups{$ParentID}{NAME};
    }  
  }
  
  if (@Parents) {
    print "<ul>\n";
    foreach my $Parent (@Parents) {
      print "<li>$Parent</li>\n";
    }  
    print "</ul>\n";
  }  
}

sub PrintGroupChildren ($) {
  my ($GroupID) = @_;

  my @HierarchyIDs = keys %GroupsHierarchy;
  my @Children = ();

  foreach my $HierarchyID (@HierarchyIDs) {
    if ($GroupID == $GroupsHierarchy{$HierarchyID}{Parent}) {
      my $ChildID = $GroupsHierarchy{$HierarchyID}{Child};
      push @Children,$SecurityGroups{$ChildID}{NAME};
    }  
  }
  
  if (@Children) {
    print "<ul>\n";
    foreach my $Child (@Children) {
      print "<li>$Child</li>\n";
    }  
    print "</ul>\n";
  }  
}

sub PrintGroupPermissions ($) {
  my ($GroupID) = @_;

  print "<ul>\n";
  print "<li>View</li>\n";
  if ($SecurityGroups{$GroupID}{CanCreate}) {
    print "<li>Create/Modify</li>\n";
  }  
  if ($SecurityGroups{$GroupID}{CanAdminister}) { # Doesn't exist yet
    print "<li>Administer</li>\n";
  }  
  print "</ul>\n";
}
1;
