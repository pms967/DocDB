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
#    Foundation, Inc., 51 Franklin Street, Fifth Floor, Boston, MA 02110-1301 USA

sub ClearEmailUsers () {
  %EmailUser         = ();
  $HaveAllEmailUsers = $FALSE;
  return;
}

sub GetEmailUserIDs () {
  my $EmailUserID;
  my @EmailUserIDs;

  my $EmailIDQuery = $dbh -> prepare("select DISTINCT(EmailUserID) from EmailUser");
  $EmailIDQuery -> execute();
  $EmailIDQuery -> bind_columns(undef,\($EmailUserID));
  while ($EmailIDQuery -> fetch) {
    FetchEmailUser($EmailUserID);
    push @EmailUserIDs,$EmailUserID;
  }
  return @EmailUserIDs;
}

sub FetchEmailUser ($) {
  my ($eMailUserID) = @_;
  my ($EmailUserID,$Username,$Password,$Name,$EmailAddress,$PreferHTML,$CanSign,$Verified,$AuthorID);

  my $UserFetch   = $dbh -> prepare(
    "select EmailUserID,Username,Password,Name,EmailAddress,PreferHTML,CanSign,Verified,AuthorID ".
    "from EmailUser where EmailUserID=?");
  
  if ($EmailUser{$eMailUserID}{EmailUserID}) {
    return $EmailUser{$eMailUserID}{EmailUserID};
  }  
  
  $UserFetch -> execute($eMailUserID);
  
  ($EmailUserID,$Username,$Password,$Name,$EmailAddress,$PreferHTML,$CanSign,$Verified,$AuthorID) = $UserFetch -> fetchrow_array;
  
  if ($Verified != 1) { # Have some weird ones out there
    $Verified = 0;
  }  
  
  $EmailUser{$EmailUserID}{EmailUserID}  = $EmailUserID;
  $EmailUser{$EmailUserID}{Username}     = $Username;
  $EmailUser{$EmailUserID}{Password}     = $Password;
  $EmailUser{$EmailUserID}{Name}         = $Name; # Construct from first/last 
  $EmailUser{$EmailUserID}{EmailAddress} = $EmailAddress;
  $EmailUser{$EmailUserID}{PreferHTML}   = $PreferHTML;
  $EmailUser{$EmailUserID}{CanSign}      = $CanSign;
  $EmailUser{$EmailUserID}{Verified}     = $Verified;
  $EmailUser{$EmailUserID}{AuthorID}     = $AuthorID;
  
  return $EmailUser{$EmailUserID}{EmailUserID};
}

sub ClearNotifications {
  $HaveAllNotifications = 0;
  %Notifications        = ();
}

sub DeleteNotifications ($) {
  my ($ArgRef) = @_;
  my $EmailUserID = exists $ArgRef->{-emailuserid} ? $ArgRef->{-emailuserid} : 0;
  
  if ($EmailUserID) { # FIXME: Don't do document specific?
    my $Delete = $dbh -> prepare("delete from Notification where Type<>'Document' EmailUserID=?");
    $Delete -> execute($EmailUserID);
  }
  
  return 0;
}

sub InsertNotifications ($) {
  my ($ArgRef) = @_;
  my $EmailUserID = exists $ArgRef->{-emailuserid} ?   $ArgRef->{-emailuserid} : 0;
  my $Period      = exists $ArgRef->{-period}      ?   $ArgRef->{-period}      : 0;
  my $Type        = exists $ArgRef->{-type}        ?   $ArgRef->{-type}        : 0;
  my @IDs         = exists $ArgRef->{-ids}         ? @{$ArgRef->{-ids}}        : ();
  
  # FIXME: Need way to insert AllDocuments and keywords (need to add text field to DB)
  
  my $Count = 0;
  if ($EmailUserID && $Period && $Type && @IDs) {
    my $Insert = $dbh -> prepare(
       "insert into Notification ".
       "(NotificationID,EmailUserID,Type,ForeignID,Period) values ".
       "(0,?,?,?,?)");
    foreach my $ID (@IDs) {
      $Insert -> execute($EmailUserID,$Type,$ID,$Period);
      ++$Count;
    }  
  }
  return $Count;
}  

sub FetchNotifications ($) {
  my ($ArgRef) = @_;
  my $EmailUserID = exists $ArgRef->{-emailuserid} ? $ArgRef->{-emailuserid} : 0;
  
  my $Count = 0;
  
  if ($EmailUserID) {
    %{$Notifications{$EmailUserID}} = (); # Erase notifications for user, not all users
    
    my ($Type,$ForeignID,$Period,$TextKey);
    my $Fetch = $dbh -> prepare("select Type,ForeignID,Period,TextKey from Notification where EmailUserID=?");
    $Fetch -> execute($EmailUserID);
    $Fetch -> bind_columns(undef,\($Type,$ForeignID,$Period,$TextKey));
    
    while ($Fetch -> fetch) {
      my $Key = $Type."_".$Period;
      if ($ForeignID) {
        push @{$Notifications{$EmailUserID}{$Key}},$ForeignID;
      }
      if ($TextKey) {
        push @{$Notifications{$EmailUserID}{$Key}},$TextKey;
      }
      ++$Count;      
    }
  }
  
  return $Count;
}

sub FetchTopicNotification ($$) { #V8OBS
  my ($EmailUserID,$Set) = @_;

  my ($MajorTopicID,$MinorTopicID);

  $Table = "EmailTopic$Set";
  @NotifyMajorIDs = ();
  @NotifyMinorIDs = ();
  $NotifyAllTopics = 0;
  
  my $UserFetch   = $dbh -> prepare("select MajorTopicID,MinorTopicID from $Table where EmailUserID=?");

# Get users interested in all documents for this reporting period

  $UserFetch -> execute($EmailUserID);
  $UserFetch -> bind_columns(undef,\($MajorTopicID,$MinorTopicID));
  while ($UserFetch -> fetch) {
    if ($MajorTopicID) {
      push @NotifyMajorIDs,$MajorTopicID;
    } elsif ($MinorTopicID) { 
      push @NotifyMinorIDs,$MinorTopicID;
    } else { 
      $NotifyAllTopics = 1;
    }  
  }
}

sub FetchAuthorNotification ($$) { #V8OBS
  my ($EmailUserID,$Set) = @_;

  my $AuthorID;

  $Table = "EmailAuthor$Set";
  @NotifyAuthorIDs = ();
  
  my $UserFetch   = $dbh -> prepare("select AuthorID from $Table where EmailUserID=?");

# Get users interested in all documents for this reporting period

  $UserFetch -> execute($EmailUserID);
  $UserFetch -> bind_columns(undef,\($AuthorID));
  while ($UserFetch -> fetch) {
    if ($AuthorID) {
      push @NotifyAuthorIDs,$AuthorID;
    }  
  }
}

sub FetchKeywordNotification ($$) { #V8OBS
  my ($EmailUserID,$Set) = @_;

  my $Keyword;

  $Table = "EmailKeyword$Set";
  @NotifyKeywords = ();
  
  my $UserFetch   = $dbh -> prepare("select Keyword from $Table where EmailUserID=?");

# Get users interested in all documents for this reporting period

  $UserFetch -> execute($EmailUserID);
  $UserFetch -> bind_columns(undef,\($Keyword));
  while ($UserFetch -> fetch) {
    if ($Keyword) {
      push @NotifyKeywords,$Keyword;
    }  
  }
  $NotifyKeywords = join ' ',@NotifyKeywords;
}

sub SetTopicNotifications ($$) { #V8OBS
  my ($EmailUserID,$Set) = @_;

  my $Table = "EmailTopic$Set";  # Tables    for immediate, daily, weekly 
  my $Field = $Set."EmailID";    # ID fields for immediate, daily, weekly  
  
# Delete all old notifications  
  
  my $Delete = $dbh -> prepare("delete from $Table where EmailUserID=?");
     $Delete -> execute($EmailUserID);

# Get parameters from input

  my $AllTopics = $params{"all$Set"};
  my @MinorIDs  = split /\0/,$params{"minortopic$Set"};
  my @MajorIDs  = split /\0/,$params{"majortopic$Set"};

# Insert into relevant tables

  if ($AllTopics) {
    my $AllInsert = $dbh -> prepare(
      "insert into $Table ($Field,EmailUserID,MinorTopicID,MajorTopicID) ".
      "            values (0,     ?,          0,           0)");
    $AllInsert -> execute($EmailUserID); 
  }
  foreach my $MinorID (@MinorIDs) {
    my $MinorInsert = $dbh -> prepare(
      "insert into $Table ($Field,EmailUserID,MinorTopicID) ".
      "            values (0,     ?,          ?)");
    $MinorInsert -> execute($EmailUserID,$MinorID); 
  }   
  foreach my $MajorID (@MajorIDs) {
    my $MajorInsert = $dbh -> prepare(
      "insert into $Table ($Field,EmailUserID,MajorTopicID) ".
      "            values (0,     ?,          ?)");
    $MajorInsert -> execute($EmailUserID,$MajorID); 
  }   
}
  
sub SetKeywordNotifications ($$) { #V8OBS
  my ($EmailUserID,$Set) = @_;

  my $Table = "EmailKeyword$Set";  # Tables    for immediate, daily, weekly 
  my $Field = "Keyword".$Set."ID"; # ID fields for immediate, daily, weekly  
  
# Delete all old notifications  
  
  my $Delete = $dbh -> prepare("delete from $Table where EmailUserID=?");
     $Delete -> execute($EmailUserID);

# Get parameters from input

  my $Keywords = $params{"keyword$Set"};
     $Keywords =~ s/^\s+//;
     $Keywords =~ s/\s+$//;
  my @Keywords = split /\s+/,$Keywords;
  
# Insert into relevant table

  my $KeywordInsert = $dbh -> prepare(
      "insert into $Table ($Field,EmailUserID,Keyword) ".
      "            values (0,     ?,          ?)");
  foreach my $Keyword (@Keywords) {
    $KeywordInsert -> execute($EmailUserID,$Keyword); 
  }   
}

sub SetAuthorNotifications ($$) { #V8OBS
  my ($EmailUserID,$Set) = @_;

  my $Table = "EmailAuthor$Set";  # Tables    for immediate, daily, weekly 
  my $Field = "Author".$Set."ID"; # ID fields for immediate, daily, weekly  
  
# Delete all old notifications  
  
  my $Delete = $dbh -> prepare("delete from $Table where EmailUserID=?");
     $Delete -> execute($EmailUserID);

# Get parameters from input

  my @AuthorIDs = split /\0/,$params{"author$Set"};

# Insert into relevant table

  foreach my $AuthorID (@AuthorIDs) {
    my $MinorInsert = $dbh -> prepare(
      "insert into $Table ($Field,EmailUserID,AuthorID) ".
      "            values (0,     ?,          ?)");
    $MinorInsert -> execute($EmailUserID,$AuthorID); 
  }   
}

sub InsertEmailDocumentImmediate (%) { #V8OBS
  my %Params = @_;
  
  my $EmailUserID = $Params{-emailuserid};
  my $DocumentID  = $Params{-docid};
  
  if ($DocumentID && $EmailUserID) {
    my $Insert = $dbh -> prepare("insert into EmailDocumentImmediate ".
                                 "(EmailDocumentImmediateID,EmailUserID,DocumentID) ".
                                 "values (0,?,?)");
    $Insert -> execute($EmailUserID,$DocumentID);
  }  
}

sub FetchEmailDocuments (%) { #V8OBS
  my %Params = @_;
  
  my $EmailUserID = $Params{-emailuserid};
  my $DocumentID;
  my @DocumentIDs;
  
  my $Select = $dbh -> prepare("select DISTINCT(DocumentID) from EmailDocumentImmediate ".
                                 "where EmailUserID=?");
  $Select -> execute($EmailUserID);
  $Select -> bind_columns(undef,\($DocumentID));
  while ($Select -> fetch) {
    push @DocumentIDs,$DocumentID; 
  }
  return @DocumentIDs;
}

1;
