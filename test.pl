# Before `make install' is performed this script should be runnable with
# `make test'. After `make install' it should work as `perl test.pl'

use constant MSWIN	=> $^O =~ /MSWin32|Windows_NT/i;

# Deal with the possibility of no display on Unix.
BEGIN { $ENV{ATRIA_FORCE_GUI} = MSWIN ? 1 : $ENV{DISPLAY} }

######################### We start with some black magic to print on failure.

# Change 1..1 below to 1..last_test_to_print .
# (It may become useful if the test is moved to ./t subdirectory.)

BEGIN { $| = 1; print "1..5\n"; }
END {print "not ok 1\n" unless $loaded;}
use ClearCase::ClearPrompt qw(clearprompt +TRIGGERSERIES);
$loaded = 1;
print "ok 1\n";

# Automatically generates an ok/nok msg, incrementing the test number.
# Returns the accumulated exit status when called with no arg.
{
    my $next = 2;
    my $final = 0;
    sub ok {
	return $final if !@_;
	my $success = shift;
	$final += !$success;
	return ($success ? '' : 'not ') . "ok @{[$next++]}\n";
    }
}

######################### End of black magic.

# Must have ClearCase to test.
my $cchome = $ENV{ATRIAHOME} || (MSWIN ? 'C:/atria' : '/usr/atria');
if (! -d $cchome) {
   my $wv = qx(cleartool pwv);
   if ($? || ! $wv) {
      print "\nNo ClearCase found on this system, skipping tests ...\n";
      exit 0
   }
}

exit 0 if $ENV{NO_INTERACTIVE_TEST_PL};

my $rc;
my @yes_no = qw(yes_no -pref -mask yes,no -type ok -prompt);

## Test 2
my $msg2 = qq(A simple test\n(of clearprompt proceed ...));
$rc = clearprompt(qw(proceed -type ok -mask p -pref -pro), "$msg2");
my $pre2 = qq(Test 2: Did you just see a dialog box saying '$msg2'?);
$rc = clearprompt(@yes_no, $pre2);
print ok($rc == 0);

## Test 3
my $msg3 = qq(Testing asynchronous use of clearprompt());
clearprompt(qw(proceed -type ok -mask p -pref -pro), "\n\n\n$msg3 ...\n\n\n");
my $pre3 = qq(Test 3: Do you see another dialog box saying '$msg3'?);
$rc = clearprompt(@yes_no, $pre3);
print ok($rc == 0);

## Test 4
my @args4 = qw(yes_no -pref -mask y,n -prompt);
my $msg4 = qq(Test 4: testing return codes - please press 'Yes');
$rc = clearprompt(@args4, $msg4);
print ok($rc == 0);

# This sequence tests text input and also "trigger series" stashing.
{
    local %ENV = %ENV;
    $ENV{CLEARCASE_SERIES_ID} = 'a1:b2:c3:d4';

    my($ptext, $prc);
    for my $seq (1..3) {
	$ENV{CLEARCASE_BEGIN_SERIES} = $seq == 1;
	$ENV{CLEARCASE_END_SERIES} =   $seq == 3;

	my @testx = qw(text -pref -prompt);
	my $msgx = qq(Test 5-10: trigger series with text prompts

	Please type some characters at the prompt:);
	my $data = clearprompt(@testx, $msgx);
	$data =~ s/"/'/g if MSWIN;
	print qq(At text prompt #$seq you entered '$data'.\n);
	print ok(defined($data) && (!defined($ptext) || $ptext eq $data));
	$ptext = $data;

	my $rcx = clearprompt(qw(yes_no -type ok -pro), "Choose any response");
	my $rcname = qw(Yes No Abort)[$rcx];
	print qq(At proceed prompt #$seq you entered '$rcname'.\n);
	print ok(defined($rcname) && (!defined($prc) || $prc eq $rcname));
	$prc = $rcname;
    }
}

exit ok();
