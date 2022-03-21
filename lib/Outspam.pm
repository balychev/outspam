package Outspam;

use warnings;
use strict;
use DBI;
use Time::Local;

use base qw(Exporter);

our @EXPORT = qw ( initproc db_connect read_config date2sec rbookmark wbookmark query_err daemonize );
#our @EXPORT = qw ( * );

sub read_config {
   my $config_file = shift;
   my $conf = shift;
   open(my $f, '<', $config_file) or die "Could not read \"$config_file\" $!";
   my $conf_line;
   while ( readline($f) ) {
       if ( /^\s*([a-z\_]+)\s+(.+)$/ ) {
          if ( defined $conf->{$1} ) {  
             $conf_line = "\$conf->{'". $1 . "'} = '" . $2 . "'";
             eval "$conf_line\n";
          }   
       }    
   }
   close($f);   
   foreach (keys(%$conf)) {
      die "\"$_\" config parameter not found or empty" if $conf->{$_} eq '';  
   }        
   return $conf;
}    

sub initproc {
   my $conf = shift; 
   foreach (keys(%$conf)) {
      $conf->{'logfile'} = $conf->{$_} if /(.*)log$/;
      $conf->{'bookmark'} = $conf->{$_} if /(.*)_bookmark$/;
   }        
   my $init = { 
     'startime' => time,
     'yearlog' => (localtime(time))[5] + 1,
   };
   rbookmark($conf,$init);
   open my $f, "<$conf->{'logfile'}" or die "$conf->{'logfile'} $!";
   $init->{'cur_first_line'} = readline $f;
   if ( defined $init->{'bm_end'} ) {
      if  ( $init->{'cur_first_line'} ne  $init->{'bm_begin'} ) {
         undef  $init->{'bm_end'};
     }   
   }    
   seek($f,0,0);
   return ($init,$f);
}    

sub date2sec {
    (my $smh, my $day, my $mon, my $init) = @_;
    my %months = qw / Jan 0 Feb 1 Mar 2 Apr 3 May 4 Jun 5 Jul 6 Aug 7 Sep 8 Oct 9 Nov 10 Dec 11 /;
    my $tm = timelocal (reverse (split(/:/,$smh)), $day, $months{$mon}, $init->{'yearlog'});
    if ( $tm gt $init->{'startime'} ) {
      --$init->{'yearlog'};
      $tm = date2sec($smh,$day,$mon,$init);
    }
    return $tm;
}

sub db_connect {
    my $conf = shift;
    my $conn = DBI->connect("DBI:mysql:$conf->{'db'}:$conf->{'dbhost'}",
                    $conf->{'dbuser'}, $conf->{'dbpassword'});
    die "Connection to database failed\n" unless $conn;
    $conn->prepare("SET SESSION sql_mode=\'\'")->execute();
    return $conn;
}    

sub query_err {
    (my $conn, my $q ) = @_;
    print "Error: query \"". $q ."\" failed\n";
    die $conn->errstr;
}

sub wbookmark {
   (my $conf, my $init, my $last_msg) = @_;
   open($b, '>', $conf->{'bookmark'}) or die "write $conf->{'bookmark'} $!";
   print $b $init->{'cur_first_line'} if defined $init->{'cur_first_line'};
   print $b $last_msg if defined $last_msg;
   close $b;
}    

sub rbookmark {
  (my $conf, my $init) = @_;
  my $log_first_line;
  my $log_last_msg;
  undef $init->{'bm_begin'};
  undef $init->{'bm_end'};
  if ( -f $conf->{'bookmark'} ) {
     open(my $b, '<', $conf->{'bookmark'}) or die "$conf->{'bookmark'} $!";
     $init->{'bm_begin'} = readline $b;
     $init->{'bm_end'} = readline $b;
     close $b;
  }
  unless ( defined $init->{'bm_begin'} && defined $init->{'bm_end'} ) {
     undef $init->{'bm_begin'};
     undef $init->{'bm_end'};
  }         
}

1;
