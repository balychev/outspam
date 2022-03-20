package Outspam;

use warnings;
use strict;

use base qw(Exporter);

our @EXPORT = qw ( read_config );

sub read_config {
   my $config_file = shift;
   my $config_param = shift;
   open(my $f, '<', $config_file) or die "Could not read \"$config_file\" $!";
   my $conf_line;
   while ( readline($f) ) {
       if ( /^\s*([a-z\_]+)\s+(.+)$/ ) {
          $conf_line = "\$config_param->{'". $1 . "'} = '" . $2 . "'";
          eval "$conf_line\n";
       }    
   }
   close($f);   
   foreach (keys(%$config_param)) {
      die "\"$_\" config parameter not found or empty" if $config_param->{$_} eq '';  
   }        
   return $config_param;
}    

1;
