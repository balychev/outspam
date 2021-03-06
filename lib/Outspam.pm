package Outspam;

use warnings;
use strict;
use DBI;
use Time::Local;
use Net::Netmask;
use Data::Dumper;

use base qw(Exporter);

our @EXPORT = qw ( initproc db_connect read_config date2sec rbookmark
                   wbookmark query_err daemonize in_mynet in_netblock sec2date subst_percent);
#our @EXPORT = qw ( * );

sub read_config {
   my $config_file = shift;
   my $conf = shift;
   open(my $f, '<', $config_file) or die "Could not read \"$config_file\" $!";
   my $conf_line;
   while ( readline($f) ) {
       s/\#.*//;
       s/\s+$//; 
       if ( /^\s*([a-z\_]+)\s+(.+)$/ ) {
          if ( defined $conf->{$1} ) {  
             my $name = $1; my $val = "\'$2\'";
             #             $val = "\'$val\'" unless $name =~ /^[\[\{]/; 
             $conf_line = "\$conf->{\'$name\'} = $val";
             eval "$conf_line\n";
          }   
       }    
   }
   close($f);   

   for my $p (qw (mynet friendnet)) {
       if ( $conf->{$p} ) {
          $conf->{$p} = [ split(/\s*,\s*/,$conf->{$p}) ];
          $conf->{$p} = [ map { Net::Netmask->new2($_) } @{$conf->{$p}} ]; 
       }    
   }
   for my $p (qw (ignore_sender)) {
      if ( $conf->{$p} ) {
         $conf->{$p} = [ split(/\s*,\s*/,$conf->{$p}) ];
      }
   }   

   for my $p (qw (mistrust msgs_sec sndr_ip_mistrust)) {
      if ( $conf->{$p} ) {
         $conf->{$p} = { split(/\s*,\s*|\s/,$conf->{$p}) };
      }
   }   

   #   foreach my $k (keys(%$conf)) {
   #   if ( $conf->{$k} =~ /^\s*([\[\{])(.+)([\]\}])\s*$/ ) {
   #       eval '$conf->{' .$k. '} = ' . $1$2$3;  
   #    }    
   #}        

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


sub sec2date {
   (my $time) = @_; 
   my @months = qw / Jan Feb Mar Apr May Jun Jul Aug Sep Oct Nov Dec /;
   (my $sec, my $min, my $hou, my $day, my $mon, my $yea) = localtime($time);
   return sprintf("%3s %-2s %02d:%02d:%02d",$months[$mon],$day,$hou,$min,$sec);
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
    warn $conn->errstr;
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

sub in_netblock {
   (my $ip, my @netblocks) = @_;
   return grep { $_ > 0 } map { $_->match($ip) } (@netblocks);
}    

sub in_mynet {
    (my $ip, my $conf) = @_;
    return grep { $_ > 0 } map { $_->match($ip) } (@{$conf->{'mynet'}});
}    

sub subst_percent {
    (my $templ, my $param ) = @_;
    if ( ref $param ) {
        foreach my $i (@$param) {
          $templ =~ s/\%/$i/;
        }
    }
    else {
        $templ =~ s/\%/$param/g;
    }    
    return $templ;
}    

1;
