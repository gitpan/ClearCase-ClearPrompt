# This script is useful for testing Net::SMTP configuration. If run with
# no arguments, eg "perl smtp.pl", it will attempt to send mail from you
# to you. You might want to "ping mailhost" since that's the default
# SMTP server, and/or search for the file "libnet.cfg" in your perl
# site/lib area and see what it thinks the SMTP server is.
# Also, you may need to modify this script to qualify your email address
# in the $smtp->to line with a domain name.

use Net::SMTP;

my $smtp = Net::SMTP->new;
exit 2 unless defined $smtp;
my $name = $ENV{CLEARCASE_USER}||$ENV{USERNAME}||$ENV{LOGNAME}||$ENV{USER};
$smtp->debug(1);
$smtp->mail($name) &&
    $smtp->to($name, {SkipBad => 1}) &&
    $smtp->data() &&
    $smtp->datasend("To: $name\n") &&
    $smtp->datasend("Subject: TESTING\n") &&
    $smtp->datasend("\n") &&
    $smtp->datasend(@ARGV ? "@ARGV" : "testing ...") &&
    $smtp->dataend() &&
    $smtp->quit;
