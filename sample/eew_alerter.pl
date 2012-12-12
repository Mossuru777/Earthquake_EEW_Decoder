#!/usr/bin/perl -w

use utf8;
use strict;
use warnings;
use LWP;
use IO::Socket;
use IO::Socket::Multicast;
use DateTime;
use DateTime::Format::Strptime;
use Encode;
use Digest::MD5 qw(md5_hex);
use Time::Local;
use FindBin;
use Net::Twitter::Lite;
use LWP::UserAgent;
use HTTP::Request::Common;
use Earthquake::EEW::Decoder;

#################################################################
# WNI Last 10-Second ユーザー設定
my $USER       = '';    # ユーザー名
my $PASS       = '';    # パスワード
#################################################################
# Log Folder設定
my $logfolder  = "$FindBin::Bin/log/";
#################################################################
# UDP MultiCast設定
my $udp_broadcast_group_and_port = "224.0.0.1:65432";  # UDPMulticastのGroupAddressとPort
#################################################################
# Twitter設定
my $consumer_key = "";
my $consumer_secret = "";
my $access_token = "";
my $access_token_secret = "";
my $nt = Net::Twitter::Lite->new(
    consumer_key => $consumer_key,
    consumer_secret => $consumer_secret,
    legacy_lists_api => 0,
);
$nt->access_token($access_token);
$nt->access_token_secret($access_token_secret);
################################################################
# im.kayac.com設定
my $im_kayac_user = "";
my $im_kayac_url = "http://im.kayac.com/api/post/$im_kayac_user";
################################################################
my $DEBUG      = 0;
my $HOST       = 'http://lst10s-sp.wni.co.jp/server_list.txt';
my $UserAgent  = 'FastCaster/1.0 powered by weathernews.';
my $ServerVer  = 'FastCaster/1.0.0 (Unix)';
my $TerminalID = '211363088';
my $AppVer     = '2.4.2';
#################################################################
my $PASS_md5 = md5_hex($PASS);
my $dt       = DateTime->now;
my $now      = $dt->strftime("%Y/%m/%d %H:%M:%S.%6N");
my $eew = Earthquake::EEW::Decoder->new();
my $udp = IO::Socket::Multicast->new();
   $udp->mcast_dest($udp_broadcast_group_and_port);
my $format = DateTime::Format::Strptime->new(
    time_zone => 'JST-9',
    pattern => '%y%m%d%H%M%S'
);

my $past_flag = 0;

# ファイル入力による過去ログ訓練モード
if(defined($ARGV[0]) && -f $ARGV[0]){
    $past_flag = 1;
    my ($fh, $filedata, $line);
    open($fh, "<", $ARGV[0]);
    while($line = <$fh>){
        $filedata .= $line;
    }
    close($fh);

    my $d = $eew->read_data($filedata);
    my @message = &makeMessage($d);
    
    # UDP Multicast
    $udp->mcast_send(encode('utf-8', $message[0] . $message[1])) if( $udp_broadcast_group_and_port );
    
    # Send to Kayac
    sendtoKayac($message[0] . $message[1]) if( $im_kayac_user && $im_kayac_url );

    exit(0);
} elsif(defined($ARGV[0])){
    exit(1);
}

# WNI ユーザー確認
if( !$USER || !$PASS ) exit(1);

# ログディレクトリ準備
if(!-e $logfolder){
    mkdir($logfolder) or die "can't create log directory!";
}

#シグナル設定
$SIG{'HUP'} = 'IGNORE';
$SIG{'INT'} = 'EndWarning';
$SIG{'KILL'} = 'EndWarning';
$SIG{'QUIT'} = 'EndWarning';
$SIG{'TERM'} = 'EndWarning';

#タイムアウト時のシグナルによる再接続処理
$SIG{'ALRM'} = 'Timeout';


WNI_INIT:
my ( $ip, $port ) = &initWNI;
WNI_CONNECT:
my $socket = IO::Socket::INET->new(
    PeerAddr => $ip,
    PeerPort => $port,
    Proto    => "tcp",
);
if(!$socket){
    sleep(5);
    goto WNI_CONNECT;
}

my $request = HTTP::Headers->new(
    'User-Agent'                  => $UserAgent,
    'Accept'                      => '*/*',
    'Cache-Control'               => 'no-cache',
    'X-WNI-Account'               => $USER,
    'X-WNI-Password'              => $PASS_md5,
    'X-WNI-Application-Version'   => $AppVer,
    'X-WNI-Authentication-Method' => 'MDB_MWS',
    'X-WNI-ID'                    => 'Login',
    'X-WNI-Protocol-Version'      => '2.1',
    'X-WNI-Terminal-ID'           => $TerminalID,
    'X-WNI-Time'                  => $now
);

$socket->send("GET /login HTTP/1.0\n");
$socket->send( $request->as_string );
$socket->send("\n");

my $PP          = 1;
my $data_length = 0;
my $LAST_ID_NUM = '';
my $fh;

$udp->mcast_send(encode('utf-8', "緊急地震速報の受信待機を開始しました。")) if( $udp_broadcast_group_and_port );
sendtoKayac("緊急地震速報の受信待機を開始しました。") if( $im_kayac_user && $im_kayac_url );

while ( my $buf = <$socket> ) {
    alarm 0; # WatchDogTimer Cancel
    # KeepAlive 受信
    if ( $buf =~ /GET \/ HTTP\/1.1/ ) {
        my $dt       = DateTime->now;
        my $now      = $dt->strftime("%Y/%m/%d %H:%M:%S.%6N");
        my $response = HTTP::Headers->new(
            'Content-Type'           => 'application/fast-cast',
            'Server'                 => $ServerVer,
            'X-WNI-ID'               => 'Response',
            'X-WNI-Result'           => 'OK',
            'X-WNI-Protocol-Version' => '2.1',
            'X-WNI-Time'             => $now
        );
        $socket->send("HTTP/1.0 200 OK\n");
        $socket->send( $response->as_string );
        $socket->send("\n");
        $socket->flush();
        $PP          = 1;
        $data_length = 0;
    }
    # データ長受信
    elsif ( $buf =~ /^Content-Length: (\d+)/ ) {
        $data_length = $1;
    }
    # EEW データ受信
    elsif ( $buf =~ /^[\r\n]+$/ ) {
        $PP = 0;
        if ($data_length) {
            my $data = '';
            read( $socket, $data, $data_length );

            my $d = $eew->read_data($data);
            my @message = &makeMessage($d);

            # UDP Multicast
            $udp->mcast_send(encode('utf-8', $message[0] . $message[1])) if( $udp_broadcast_group_and_port );

            # Send to Kayac
            sendtoKayac($message[0] . $message[1]) if( $im_kayac_user && $im_kayac_url );

            # Tweet
            if( $consumer_key && $consumer_secret && $access_token && $access_token_secret ){
                $nt->update($message[1], $d->{'center_lat'}, $d->{'center_lng'});
                $nt->update($message[0]) if($message[0]);
            }
            
            my $format = DateTime::Format::Strptime->new(
                       time_zone => 'JST-9',
                       pattern => '%Y%m%d%H%M%S'
            );
            my $eq_time = $format->parse_datetime($d->{'eq_id'});
            my $eq_time_str = $eq_time->strftime('%Y%m%d%H%M%S');
            my $warn_num = ($d->{'warn_state_code'} . $d->{'warn_num_str'}) * 1;
            if( open($fh, ">", $logfolder . $eq_time_str . "_" . $warn_num . ".txt") ){
                print $fh $data;
                close($fh);
            }
        }
        $data_length = 0;
    }
    # 接続試行時の結果受信
    elsif ( $buf =~ /X-WNI-Result: (.+)$/ ) {
        print $1,"\n";
    }
    elsif ( !$PP ) {
        print $PP, ':', $buf if ($DEBUG);
        chomp $buf;
    }
    elsif ($DEBUG) {
        print $PP, ':', $buf;
        chomp $buf;
    }
    # WatchDogTimer Set
    alarm 300; # 5 minutes
}
alarm 0;

if($socket){
    $socket->close();
}

$udp->mcast_send(encode('utf-8', "緊急地震速報が受信できない状態です。\nサーバーへの接続を再試行します。")) if( $udp_broadcast_group_and_port );
sendtoKayac("緊急地震速報が受信できない状態です。\nサーバーへの接続を再試行します。") if( $im_kayac_user && $im_kayac_url );

goto WNI_INIT;
exit 255;

sub initWNI {
    my @SERVERS;
    my $ua = LWP::UserAgent->new;
    $ua->agent($UserAgent);

    my $req = HTTP::Request->new( GET => $HOST );
    my $res = $ua->request($req);
    if ( $res->is_success ) {
        @SERVERS = split /[\r\n]+/, $res->content;
    }
    else {
        print "Error: " . $res->status_line . "\n";
        exit;
    }

    my $sum = @SERVERS;
    my ( $ip, $port ) = split /:/, $SERVERS[ int( rand($sum) ) ];
    return ( $ip, $port );
}

sub makeMessage (\$) {
    my $d = $_[0]; # EEW Decoded Data
    my @brd_msg = ("", "");
    my $line_count = 0;    
    if($past_flag){
        $brd_msg[0] .= "*** これは過去ログを使った訓練報です ***\n";
        $line_count++;
    }

    if($d->{'msg_type_code'} == 00){

        if(defined($d->{'EBI'})){
            if(defined($d->{'EBI'}->{'350'})){
                $brd_msg[0] .= _analyzeAreaMessage($d, 350);
                $line_count++;
            }
            if (defined($d->{'EBI'}->{'341'})) {
                $brd_msg[0] .= _analyzeAreaMessage($d, 341);
                $line_count++;
            } elsif (defined($d->{'EBI'}->{'340'})) {
                $brd_msg[0] .= _analyzeAreaMessage($d, 340);
                $line_count++;
            }
            foreach my $key (keys(%{$d->{'EBI'}})){
                if($line_count == 6){
                    last;
                }
                if($key eq 9999 || $key eq 350 || $key eq 341 || $key eq 340){
                    next;
                }
                $brd_msg[0] .= _analyzeAreaMessage($d, $key);
                $line_count++;
            }
            $brd_msg[0] .= "\n";
        } elsif($d->{'code'} eq '35') {
            $brd_msg[0] .= "各地の予想震度は発表されていません\。n" .
                                    "予想される最大震度は  " . $d->{'shindo'} . "  です。\n\n";
        }
        
        my $occurrence_time = $format->parse_datetime($d->{'eq_time'});
        my $publish_time = $format->parse_datetime($d->{'warn_time'});
        my $warn_num;
        if($d->{'warn_state_code'} == 9){
            $warn_num = "最終報";
        } else {
            $warn_num = "第".$d->{'warn_num'}."報";
        }
        $brd_msg[1] .= "【" . $warn_num . "  " . $publish_time->strftime('%k:%M:%S') . " 発表】(" . $occurrence_time->strftime('%k:%M:%S') . " 地震発生)\n" .
                                "  " . $d->{'center_name'} . " 深さ" . $d->{'center_depth'} . "km  ";
        if($d->{'code'} =~ /3[6|7]/){
            $brd_msg[1] .= "で  M" . $d->{'magnitude'} . "  ";
        }
        $brd_msg[1] .= "の地震\n" .
                                "  " . "予想される最大震度は  " . $d->{'shindo'} . "  です。\n";
    } elsif($d->{'code'} == 39){
        $brd_msg[1] = "【速報取り消し】\n" .
                             "  " . "先ほどの緊急地震速報は、取り消されました。";
    }
    return @brd_msg;
}

sub _analyzeAreaMessage(\$\$){
    my $d = $_[0];
    my $no = $_[1];

    my $ret_msg = "  " . $d->{'EBI'}->{$no}->{'name'} . "   ";
    if($d->{'EBI'}->{$no}->{'arrive_code'} == 00){
        my $now_time = DateTime->now(time_zone => 'JST-9');
        my $future_time = $format->parse_datetime($now_time->strftime('%y%m%d') . $d->{'EBI'}->{$no}->{'time'});
        if($future_time < $now_time){
            $future_time->add( days => 1 );
        }
        my $duration_time = $future_time->delta_ms($now_time);
        if($duration_time->in_units('minutes') != 0){
            $ret_msg .= $duration_time->in_units('minutes') . "分 ";
        }
        $ret_msg .= $duration_time->seconds . "秒後に到達   ";
    } else {
        $ret_msg .= "既に到達と予想   ";
    }
    $ret_msg .= $d->{'EBI'}->{$no}->{'shindo1'} . "\n";

    return $ret_msg;
}

sub sendtoKayac {
    no warnings;
    if($_[0]){
        my %postdata = ( 'message' => $_[0] );
        my $request = POST( $im_kayac_url, \%postdata );
        my $ua = LWP::UserAgent -> new;
        $ua -> request( $request );
    }
}

sub EndWarning {
    $udp->mcast_send(encode('utf-8', "緊急地震速報受信サービス 停止しました。")) if( $udp_broadcast_group_and_port );
    sendtoKayac("緊急地震速報受信サービス 停止しました。") if( $im_kayac_user && $im_kayac_url );
    $socket->close();
    exit 255;
}

sub TimeOut {
    $socket->close();
}
