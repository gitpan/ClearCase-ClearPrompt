# Before `make install' is performed this script should be runnable with
# `make test'. After `make install' it should work as `perl test.pl'

# Deal with the possibility of no display on Unix.
BEGIN { $ENV{ATRIA_FORCE_GUI} = $^O =~ /win32/i ? 1 : $ENV{DISPLAY} }

######################### We start with some black magic to print on failure.

# Change 1..1 below to 1..last_test_to_print .
# (It may become useful if the test is moved to ./t subdirectory.)

BEGIN { $| = 1; print "1..5\n"; }
END {print "not ok 1\n" unless $loaded;}
use ClearCase::ClearPrompt qw(:all);
$loaded = 1;
print "ok 1\n";

# Automatically generates an ok/nok msg, incrementing the test number.
{
   my $next = 2;
   sub ok {
      my $status = shift;
      return ($status ? '' : 'not ') . "ok @{[$next++]}\n";
   }
}

######################### End of black magic.

# Must have ClearCase to test.
my $cchome = $ENV{ATRIAHOME} || ($^O =~ /win32/i ? 'C:/atria' : '/usr/atria');
if (! -d $cchome) {
   my $wv = qx(cleartool pwv);
   if ($? || ! $wv) {
      print "\nNo ClearCase found on this system, skipping tests ...\n";
      exit 0
   }
}

my($rc, $final);
my @yes_no = qw(yes_no -pref -mask yes,no -type ok -prompt);

## Test 2
my $msg2 = qq(A simple test\n(of clearprompt proceed ...));
$rc = clearprompt(qw(proceed -type ok -mask p -pref -pro), "$msg2");
my $pre2 = qq(Test 2: Did you just see a dialog box saying '$msg2'?);
$rc = clearprompt(@yes_no, $pre2);
print ok($rc == 0);
$final |= $rc;

## Test 3
my $msg3 = qq(Testing asynchronous use of clearprompt());
clearprompt(qw(proceed -type ok -mask p -pref -pro), "\n\n\n$msg3 ...\n\n\n");
my $pre3 = qq(Test 3: Do you see another dialog box saying '$msg3'?);
$rc = clearprompt(@yes_no, $pre3);
print ok($rc == 0);
$final |= $rc;

## Test 4
my @args4 = qw(yes_no -pref -mask y,n -prompt);
my $msg4 = qq(Test 4: testing return codes - please press 'Yes');
$rc = clearprompt(@args4, $msg4);
print ok($rc == 0);
$final |= $rc;

## Test 5
my $dir = clearprompt_dir('.', "Choose a directory");
print qq(You chose directory '$dir'.\n); print ok(defined $dir && -d $dir);
$final |= $rc;

## Test 6
my @test6 = qw(text -pref -prompt);
my $msg6 = qq(Test 6: testing 'clearprompt(@test6 ...)'

   Please type some characters at the prompt:);
my $data = clearprompt(@test6, $msg6);
$data =~ s/"/'/g if $^O =~ /win32/i;
print qq(At the previous prompt, you entered '$data'.\n);
print ok(defined($data));

exit ($final != 0);
