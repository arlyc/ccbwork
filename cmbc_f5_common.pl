#!/usr/bin/perl
use strict;
use warnings;
use Opsware::NAS::Connect;

####################################################################################
# script name   : cmbc_f5_common.pl
# editor name   : wangjianlong 18566756311
# create time   : 2015-05-06
# last edit time : 2015-08-13
# info           : ���ű����ղ����磺perl cmbc_f5_common.pl $ACTIONS  $VS_LIST $SITE
#####################################################################################

###################################   update log #########################################
# 2015-08-13:
#    1�������Ƴ�F5�豸�ķ�ʽ Ϊ  $con->disconnect("quit");
#
# 2015-08-07:
#    1����run_cmd�����е��������Ļ�ϵ��������������Ź��ˣ���ֹOO���NA���н��Ϊ���ܱ���
# 2015-08-06:
#    1����syncͬ���Ƿ�ɹ����жϻ��ƽ������Ż�����
#    2����node�ڵ�Ĳ����Ƿ�ɹ����жϻ��ƽ����˸���
#    3�������˶�syncͬ���жϵ�ʱ�����ƣ�Ŀǰ�趨Ϊ10s��
# 2015-07-13: 
#    1������������������������F5�豸�ķ�ʽ
#    2����Ҫ�������������һ����4̨F5��ɼ�Ⱥ������2̨����ʿ2̨����ֻ��һ̨��active����״̬��ʱ�̱仯��
#    3�����Ǵ��ڻ����4̨�����ű�ͬ��֧��
#    4��������sync�ĳɹ����ļ����ƣ�����Ҫ����������ʵ�ʲ��ԣ����������õ�ʱ��ע��۲������ķ��ؽ��
#     ȷ���жϵ�����û������
# 2015-06-15:
#    1����check=true����ģ������
#    2����check=true�����ÿ�����������������ִ�в�ѯ����
#    3�������ʽ΢��
# 2015-06-09:
#    1��ÿ������ຯ�����������жϵ�ǰ״̬�Ƿ��Ѿ����Ͻ�Ҫ�����״̬�Ĺ��ܣ�
#     ���Ƿ��ϼ������ٴ�ִ�б�������ǲ����ϣ�ִ�б��
#    2��������check=true�Ĺ��ܣ����ű������Ƿ�Ϊ��������
#    3���Ż��˽ű�����ܹ�,��������˽ű�����ԺͿ���չ��
#    4���Ż��˺�������͵���
#    5�����syncͬ�����ܲ��ԣ���������ֻ��һ̨F5�豸��ͬ������ʵ��û�������ã�������Ҫ��һ������������������в���
# 2015-05-06:
#    1������F5ͨ�ýű�����Ҫʵ�ֵĹ��ܣ�VS_CHECK VS_ENABLED VS_DISABLED MEMBER_CHECK POOL_CHECK NODE_CHECK NODE_ENABLED NODE_DISABLED SYNC
#    2��ͨ���˲��Ի�������
#    3��ͬ��sync�Ĺ�����ʱ���ܲ��ԣ���Ҫ�ȴ�֪ͨ   
######################################################################################

##########################################################################################
## ����NA����
our ($f5_device_ip,$F5_DEVICE_LIST,$ACTIONS,$SITE,$CHECK,$VS_LIST);
our $host = '127.0.0.1';
our $port = '8023';
our $user = 'admin';
our $pass = 'opsware';
our $sleep_time = 10 ; #�ò�������ѭ�����ͬ���Ƿ�ɹ��Ĵ�����ÿ������һ�룬������������ֵ���һ�δ�жϳ�ͬ���ɹ���Ϊʧ�ܣ�

##########################################################################################
# ��ô���ű��Ĳ���
# VS_CHECK VS_ENABLED VS_DISABLED MEMBER_CHECK POOL_CHECK NODE_CHECK NODE_ENABLED NODE_DISABLED SYNC

$ACTIONS = '$ACTIONS$';      #�����룬���Ƕ���м���Ӣ��,����
$VS_LIST = '$VS_LIST$';     #���е�F5��Ϣ����ʽ vs1,vs2,vs3;;mp_ip1,mp_ip2...;;pbs_ip1,pbs_ip2... 
$SITE = '$SITE$';      #���߽ű��˴���Ҫ���Ĳ��������ĸ������������Ӣ��,����
$CHECK = '$check$';      #check��Ϊtrue�����ʾ���νű�����Ϊ��������  

#$ACTIONS = 'SYNC';
#$SITE = 'MP'; #PBS MP
#$CHECK = 'true'; #true
####$VS_LIST = "pes_14050_vs,pes_14050_vs;;197.3.133.209,197.3.133.209;;197.3.133.238,197.3.133.238";
#$VS_LIST = "NPS_15060_vs,NPS_15070_vs,NPS_15080_vs,NPS_15090_vs,NPS_16000_vs,NPS_17060_vs,NPS_30509_vs,NPS_30544_vs,NPS_30545_vs,NPS_4100_vs,NPS_50000_vs,NPS_5100_vs;;40.56.0.68,40.56.0.69,40.56.0.70,40.56.0.71,40.56.0.72;;40.56.0.82,40.56.0.83,40.56.0.84;;40.0.32.481,40.0.32.428";
#$VS_LIST = "neibuzijinguanli_52100_vs;;40.38.82.11,40.38.82.12;;40.38.82.14;;40.0.32.32,40.0.32.33,40.0.32.40,40.0.32.41";
##########################################################################################
# �������Զ���
our $ACTION_STR = "VS_CHECK VS_ENABLED VS_DISABLED MEMBER_CHECK POOL_CHECK NODE_CHECK NODE_ENABLED NODE_DISABLED SYNC";
our @LOG;             #�������ִ�й����Լ����ս��
our @ERROR;           #��������Ƿ���ȷִ��
our @F5_INFO ;        #��Ų�ѯ����F5��Ϣ

##########################################################################################
# ������ʼ��

# ȥ���������
$ACTIONS =~ s/"//g;$ACTIONS =~ s/\s+//g;$VS_LIST =~ s/"//g;$VS_LIST =~ s/\s+//g;

# ���������
our @ACTIONS = split /,/,$ACTIONS;    #���Ƕ�������룬����з���
our $result_string_forDB = join("-",@ACTIONS); #Ϊ�����OO�ű�ִ�н����׼��
our @info = split /;;/,$VS_LIST;      #���������Ϣ���з������

# ���VS_LIST�Ƿ����  ��vsname;;����node�ڵ�;;����ʿnode�ڵ㡱   �ĸ�ʽ
if ($#info ne 3){
 print "[ FAILURE ]: Init F5 info failed from outside, no vsnames or mapo(pengboshi)'s node IP!\n";
 print "   F5 INFO : $VS_LIST \n\n";
 print "[ FAILURE ]: Net-$result_string_forDB-failure !...\n\n"; exit 1;
}
# ����Ƿ�֧�� action
foreach my $sub_action(@ACTIONS){
 if($ACTION_STR !~ /$sub_action/){
  print "[ FAILURE ]: The action [$sub_action] isn't support in [ $ACTION_STR ]\n";exit 1;
 }
}

our $VS_STR = $info[0];our $MP_SITE_STR = $info[1];our $PBS_SITE_STR = $info[2];
$F5_DEVICE_LIST = $info[3];
print "\n------------ VALUES ------------\n\n";
print "[ F5 Device LIST ] : $F5_DEVICE_LIST\n";
print "[ ACTIONS ]        : $ACTIONS\n";
print "[ SITE ]           : $SITE\n";
print "[ F5 info ]        : $VS_LIST\n";
print "[ CHECK ]          : $CHECK\n";
print "[ VS STRING ]      : $VS_STR\n";
print "[ MP SITE STRING ] : $MP_SITE_STR\n";
print "[ PBS SITE STRING ]: $PBS_SITE_STR\n\n";


##########################################################################################
# ׼������

# ��½NA��F5�豸
our $con = Opsware::NAS::Connect->new(-user => $user,-pass => $pass,-host =>$host,-port =>$port);
# �ж��Ƿ��½HP NAϵͳ�ɹ�
if(!$con->login()){
 print "[ FAILURE ]: Can't login NA !\n[ FAILURE ]: Net-$result_string_forDB-failure !...\n\n"; exit 1;
}else{
 print "[ SUCCESS ]: login to [ HP NA ] success \n";
}

# �ж��Ƿ�ͨ��HP NA��½�豸�ɹ�
sub check_active{
 my $prompt = qr/\#/m;
 foreach my $f5 (split /,/,$F5_DEVICE_LIST){
  print "[ SUCCESS ]: we will try connect to F5 device [ $f5 ] \n";
  if(!$con->connect($f5,$prompt)){
   print "[ FAILURE ]: Can't connect [ $f5 ],we will try another f5 device ! \n";
   next;
  }else{
   print "[ SUCCESS ]: connect to F5 [ $f5 ] by [ HP NA ] success \n\n";
  }
  
  my $cmd = "show sys failover \n";
  my @output = $con->cmd($cmd);
  my $result = join("\n",@output);
  print "[ SUCCESS ]: check F5 [ $f5 ] whether is active ...\n";
  if ($result =~ /Failover active/i){
   print "[ SUCCESS ]: the F5 [ $f5 ] is active! \n";
   return "active:$f5"
  }else{
   print "[ WARNING ]: the F5 [ $f5 ] is not active,we will try another ...\n";
   #$con->cmd('quit\n');
   #$con->cmd('exit\n');
   $con->disconnect("quit");

  }
 }
 return "standby"
}

our $check_result = &check_active;
if ($check_result !~ /active/i){
 print "[ FAILURE ]: the f5 list [$F5_DEVICE_LIST] has not active device! please check...\n";
 $con->logout();
 undef $con;
 exit 1;
}


# �ж��Ƿ�����������������������ؼ���Ȼ���˳��ű����������������������ִ��
if($CHECK =~ /true/i){
 #VS_CHECK VS_ENABLED VS_DISABLED MEMBER_CHECK POOL_CHECK NODE_CHECK NODE_ENABLED NODE_DISABLED SYNC
 if($ACTIONS =~ /vs/i){
  &check_vs_status($_,"NoInsertERROR") foreach(split /,/,$VS_STR);
 }elsif($ACTIONS =~ /NODE/i){
  &check_node_status($MP_SITE_STR,'NoInsertERROR') if ($SITE =~ /MP/i);
  &check_node_status($PBS_SITE_STR,'NoInsertERROR') if($SITE =~ /PBS/i);
 }elsif($ACTIONS =~ /POOL|MEMBER/i){
  &others_action();
 }

 print "[ SUCCESS ]: Net-$result_string_forDB-success !...\n\n";
 #print "[ SUCCESS ]: check=$CHECK,will run for Desktop Show \n\n";
 #if ($#ERROR > -1 ){
 # print "[ FAILURE ]: Net-$result_string_forDB-failure !...\n\n";
 # exit 1;
 #}else{
 # print "[ SUCCESS ]: Net-$result_string_forDB-success !...\n\n";
 #}

 
 #$con->cmd('quit\n');$con->cmd('exit\n');
 $con->disconnect("quit");
 $con->logout(); undef $con;
 #print "[ SUCCESS ]: Net-$result_string_forDB-success !...\n\n";
 exit;
}

##########################################################################################
# ������ຯ��

# ��������ִ�к���
sub run_cmd{
 my ($cmd) = @_;
 my $cmd_print = $cmd;
 #$cmd_print =~ s/\^//g;#$cmd_print =~ s/\|//g;
 print "\n[ SUCCESS ]: execute cmd [ $cmd_print ]\n";
 my @output = $con->cmd($cmd);
 my $result = join("\n",@output);
 $result =~ s/\^//g;
 push @LOG,$result;
 return $result;
}
# ����vs��麯��
sub check_vs_status{
 my ($vs_name,$insert_error) = @_;
 my $cmd = "show ltm virtual $vs_name";
 my $result = &run_cmd($cmd);
 my $str_re = '';
 if ($insert_error !~ /NoInsertERROR/i){
  $str_re = "Availability";
 }else{
  $str_re = "State";
 }
 $result =~ /$str_re\s+:\s+(.*)\n/i;
 my $status = $1;$status =~ s/\s+//g;
 if($result =~ /$str_re\s+:\s+available/i){
  print "[ SUCCESS ]: The ltm virtual [ $vs_name ]'s $str_re is [ $status ]\n";  
 }else{
  print "[ FAILURE ]: The ltm virtual [ $vs_name ]'s $str_re is [ $status ]\n";
  push @ERROR,$result if not $insert_error =~ /NoInsertERROR/i;
 }
 return $status
}
# ����vs��������
sub start_or_stop_vs{
 my ($action,$vs_name_list) = @_;
 my $print_str="start";
 $print_str = "stop" if $action =~ /disable/i ;
 my @vs_name_list = split /,/,$vs_name_list;
 foreach my $vs_name(@vs_name_list){
  my $cmd = "modify ltm virtual $vs_name $action";
  my $now_status = "init";
  $now_status = &check_vs_status($vs_name,"NoInsertERROR");
  if ($action !~ /$now_status/i){
   my $result = &run_cmd($cmd);
   my $return_cmd_run=`echo "$result"|grep -v "modify"`;chomp($return_cmd_run);$return_cmd_run =~ s/\s+//g;
   if($return_cmd_run){
    print "[ FAILURE ]: The vs [ $vs_name ] $print_str failure\n";
    push @ERROR,$result;
   }else{
    print "[ SUCCESS ]: The vs [ $vs_name ] $print_str success\n";
   }
  }else{
   print "[ WARNING ]: The vs [ $vs_name ] status is [ $now_status ],unnecessary change\n\n"; 
  }
 }
}
# ����NODE��麯��
sub check_node_status{
 # ����insert_error�ַ�����Ϊ�˷�����ͣnode���м��
 my ($node_ip_list,$insert_error) = @_;
 my @node_ip_list = split /,/,$node_ip_list;
 #print "[ SUCCESS ]: the node ip list is [ $node_ip_list ]\n";
 my $status='';
 foreach my $node_ip(@node_ip_list){
  if ($node_ip =~ /(\d{1,3}\.\d{1,3}\.\d{1,3}\.\d{1,3})/i){
   my $node_ip = $1;
   my $cmd = "show ltm node $1";
   my $result = &run_cmd($cmd);
   $result =~ /State\s+:\s+(.*)\n/i;
   $status = $1;$status =~ s/\s+//g;
   if($result =~ /State\s+:\s+enabled/i){
    print "[ SUCCESS ]: The node [ ",$node_ip," ] State is [ $status ]\n";  
   }elsif($result =~ /State\s+:\s+disabled/i){
    print "[ FAILURE ]: The node [ ",$node_ip," ] State is [ $status ]\n";
    push @ERROR,$result if not $insert_error =~ /NoInsertERROR/i;
   }elsif($result =~ /State/i){
    print "[ FAILURE ]: The node [ ",$node_ip," ] State is [ $status ]\n";
    push @ERROR,$result if not $insert_error =~ /NoInsertERROR/i;
   }else{
    print "[ FAILURE ]: The node [ ",$node_ip," ] State can't find\n";
    push @ERROR,$result if not $insert_error =~ /NoInsertERROR/i;
   }
  }else{
   print "[ WARNING ]: The [$node_ip] is not a IP list \n";
   push @ERROR,"The [$node_ip] is not a IP list \n";
  }
 }  
 return $status;
}
# ����node��ͣ����
sub start_or_stop_node{
 #&start_or_stop_node("session user-enabled",$members_name);
 my ($action,$node_ip_list) = @_;
 my @node_ip_list = split /,/,$node_ip_list;
 my $print_str="start";
 $print_str = "stop" if $action =~ /disable/i ;
  
 foreach my $node_ip(@node_ip_list){
  my $now_status = "init";
  $now_status = &check_node_status($node_ip,"NoInsertERROR");
  if($action !~ /$now_status/i ){
   if( $now_status =~ /\d+/i){
    #print "[ FAILURE ]: The node [ $node_ip ] will not do [ $print_str ]\n";
    push @ERROR,"[ FAILURE ]: The node [ $node_ip ] will not do [ $print_str ]\n";
    next;
   }
   if ($node_ip =~ /(\d{1,3}\.\d{1,3}\.\d{1,3}\.\d{1,3})/i){
    my $node_ip = $1;
    my $cmd = "modify ltm node $node_ip $action";
    my $result = &run_cmd($cmd);
    my $return_cmd_run=`echo "$result"|grep -v "modify"`;chomp($return_cmd_run);$return_cmd_run =~ s/\s+//g;
 my $node_status_afterdo ;
 $node_status_afterdo = &check_node_status($node_ip,'NoInsertERROR') ;

    #if($return_cmd_run){
 print "print_str:$print_str:$node_status_afterdo\n";
 if($print_str eq 'stop'){
  if( $node_status_afterdo !~ /disable/i){
   print "[ FAILURE ]: The node [ $node_ip ] $print_str failure\n";
   push @ERROR,$result;
  }else{
   print "[ SUCCESS ]: The node [ $node_ip ] $print_str success\n";
  }
 }elsif($print_str eq'start'){
  if( $node_status_afterdo !~ /enable/i){
   print "[ FAILURE ]: The node [ $node_ip ] $print_str failure\n";
   push @ERROR,$result;
  }else{
   print "[ SUCCESS ]: The node [ $node_ip ] $print_str success\n";
  } 
 }else{
  print "[ FAILURE ]: The node [ $node_ip ] $print_str failure\n";
  push @ERROR,$result;
 }
 
 
   }else{
  print "[ WARNING ]: The [$node_ip] is not a IP list\n";
  push @ERROR,"The [$node_ip] is not a IP list \n";
   }
  }else{
   print "[ WARNING ]: The node [ $node_ip ] status is [ $now_status ],unnecessary change\n\n"; 
  }
 }
}
# ����pool��麯��
sub check_pool_status{
 my ($poolname) = @_;
 my $cmd = "show ltm pool $poolname";
 my $result = &run_cmd($cmd);
 $result =~ /Availability\s+:\s+(.*)\n/i;
 my $status = $1;$status =~ s/\s+//g;
 if($result =~ /Availability\s+:\s+available/i){
  print "[ SUCCESS ]: The pool [ ",$poolname," ]'s Availability is [ $status ]\n";  
 }else{
  print "[ FAILURE ]: The pool [ ",$poolname," ]'s Availability is [ $status ]\n";
  push @ERROR,$result if($CHECK !~ /true/i);
 }
}
# ����member��麯��
sub check_member_status{
 my($pool_name,$members) = @_;
 my @members = split /,/,$members;  
 foreach my $member(@members){
  my $cmd = "show ltm pool $pool_name members { $member }";
  my $result = &run_cmd($cmd);
  $result =~ /\s+Availability\s+:\s+(.*)\n/i;
  my $status = $1;
  $status =~ s/\s+//g;
  if($result =~ /\s+Availability\s+:\s+available/i){
   print "[ SUCCESS ]: The [ $SITE ] pool member [ $member ]'s Availability is [ $status ]\n";  
  }else{
   print "[ FAILURE ]: The [ $SITE ] pool member [ $member ]'s Availability is [ $status ]\n";
   push @ERROR,$result if($CHECK !~ /true/i);
  }
 }
}
# ����ͬ������
sub SYNC{
 my $cmd = "list cm device-group";
 my $result = &run_cmd($cmd);
 if($result =~ /\s+(device-group-failover.*) /i){
 my $sync_group_name = $1;
 $cmd = "run cm config-sync to-group $sync_group_name";
 $result = &run_cmd($cmd);
 #my $return_cmd_run=`echo "$result"|grep -v "run"`;chomp($return_cmd_run);$return_cmd_run =~ s/\s+//g;
 my $sync_check_cmd='show cm sync-status | grep ^Status';
 
 my $get_sync_status='syncfailure';
 foreach(1..$sleep_time){
  my $sync_status = &run_cmd($sync_check_cmd);
  $sync_status=`echo "$sync_status"|grep -v "show cm"`;chomp($sync_status);
  #$sync_status =~ s/\^//g;#$sync_status =~ s/\|//g;
  $sync_status=~s/[^0-9a-zA-Z| ]//g;
  if($sync_status =~ /In Sync/i){
   print "[ SUCCESS ]: get sync status [$sync_status] \n";
   print "[ SUCCESS ]: SYNC success\n";
   $get_sync_status='syncsuccess';
   last;
  }
  print "[ FAILURE ]: get sync status [$sync_status],wait next check...\n";
  sleep(1);
 }
 if ($get_sync_status !~ /syncsuccess/){
  print "[ FAILURE ]: SYNC failure\n";
  push @ERROR,$get_sync_status;
 }
 }else{
  print "[ FAILURE ]: sync failure because of can't get the group name\n";
  push @ERROR,"sync failure because of can not get group name";  
 }  
}
# ���嵥��vs��Ϣ��ѯ����
sub get_info{
 my ($vs_name) = @_;
 my $cmd_vs = "list ltm virtual $vs_name";
 my @output_vs = $con->cmd($cmd_vs);
 my $result_vs = join("\n",@output_vs);
 push @LOG,$result_vs;
 my @vs_members = ($result_vs =~ /pool\s+(.*)\n/gi);
 if(@vs_members){
  my $pool_name = $vs_members[0] ;
  my $cmd_pool = "list ltm pool $pool_name";
  my @output_pool = $con->cmd($cmd_pool);
  my $result_pool = join("\n",@output_pool);
  push @LOG,$result_pool;
  #my @IP_matches = ($result_pool =~ /(\d{1,3}\.\d{1,3}\.\d{1,3}\.\d{1,3}:\d+)/gi);
  my @IP_matches = ($result_pool =~ /(\d{1,3}\.\d{1,3}\.\d{1,3}\.\d{1,3}:.*) /gi);
  if(@IP_matches){
   my $pool_members_string = join(",",@IP_matches);
   my $info = $vs_name.";".$pool_name.";".$pool_members_string;
   print "$vs_name          $info\n";
   push @F5_INFO,$info;
  }else{
   print "[ FAILURE ]: Can't get the $pool_name 's members info\n";
   push @ERROR,"Can't get the $pool_name 's members info";
  }
 }else{
  print "[ FAILURE ]: Can't get the $vs_name 's info\n";
  push @ERROR,"Can't get the $vs_name 's info";
 }
}
#������vs��Ϣ��ѯ����
sub init_get_info{
 $VS_STR =~ s/\s+//g;
 print "[ SUCCESS ]: Begin search the vs info...\n\n";
 print "vsname                    vs info\n";
 &get_info($_) foreach split /,/,$VS_STR;
}
# ������Ҫ��F5���Ȼ�ȡ��Ϣ���ٽ��в�����action����; ACTION��POOL_CHECK��MEMBER_CHECK
sub others_action{
 &init_get_info();
 our @PBS_SITE_STR = split /,/,$PBS_SITE_STR; #�û����������ʿ��node�ڵ����
 our @MP_SITE_STR = split /,/,$MP_SITE_STR; #�û���������µ�node�ڵ����

 foreach my $SUB_ACTION(@ACTIONS){
  #print "\n------------",$SUB_ACTION," RESULT------------\n\n";
  foreach my $sub_info(@F5_INFO){
   print "\n[ SUCCESS ]: f5 string [ $sub_info ]\n";
   our @node_str; #�û������node���豸�ϵĽ���ƥ�䣬������������
   our @sub_info = split /;/,$sub_info; #��ȫ���豸�ϵ���Ϣ�ٷ���
   if ($SITE =~ /MP/i){
    #foreach my $sub_node(@MP_SITE_STR){
    # if ($sub_info =~ /($sub_node:\d+)/i){
    #  push @node_str,$1;
    # }else{
    #  print "[ FAILURE ]: The node [ $sub_node ] is not in F5 device \n";
    #  push @ERROR,"[ FAILURE ]: The node [ $sub_node ] is not in F5 device \n";
    # }
    #}
   }elsif ($SITE =~ /PBS/i){
    #foreach my $sub_node(@PBS_SITE_STR){
    # if ($sub_info =~ /($sub_node:\d+)/i){
    #  push @node_str,$1;
    # }else{
    #  print "[ FAILURE ]: The node [ $sub_node ] is not in F5 device \n";
    #  push @ERROR,"[ FAILURE ]: The node [ $sub_node ] is not in F5 device \n";
    # }
    #}
   }else{
    print "[ FAILURE ]: The operation site is not MP or PBS \n";
    push @ERROR,"[ FAILURE ]: The operation site is not MP or PBS \n" if($CHECK !~ /true/i);
   }
 
   my %count;our @strs = grep {++$count{$_}<2} @node_str; #ȥ�ظ�
   our $sub_info_dealed = $sub_info[0].";".$sub_info[1].";".join(',',@strs); #���յ���Ҫ���豸��ִ�ж�����Ŀ����Ϣ 
   #&main($SUB_ACTION,$sub_info_dealed) if ($#ERROR < 0); #���д���ִ�в���
   
   # ���ݲ����뿪ʼ���豸��ִ�в���
   if($SUB_ACTION eq 'POOL_CHECK'){
    &check_pool_status($sub_info[1]);
   }elsif($SUB_ACTION eq 'MEMBER_CHECK'){
    &check_member_status($sub_info[1],join(',',@strs));
   }else{
    print "[ FAILURE ]: The action [$SUB_ACTION] is not in ACTION_STR [$ACTION_STR]\n";
 if($CHECK !~ /true/i){
  push @ERROR,"The action [$SUB_ACTION] is not in ACTION_STR [$ACTION_STR]";
 }
    
   }
   
   
  }
 }
}
# ������
sub main{
 my ($ACTIONS) = @_;
 if ($ACTIONS =~ /SYNC/i) {
  &SYNC;
 }elsif($ACTIONS =~ /NODE/i){
  our $nodelist='';
  $nodelist=$MP_SITE_STR if ($SITE =~ /MP/i) ;  
  $nodelist=$PBS_SITE_STR if($SITE =~ /PBS/i);
  $nodelist=$MP_SITE_STR.",".$PBS_SITE_STR if($SITE =~ /PBS/i and $SITE =~ /MP/i);
 
  if ($ACTIONS =~ /NODE_CHECK/i) {
   &check_node_status($MP_SITE_STR,'InsertERROR') if ($SITE =~ /MP/i);
   &check_node_status($PBS_SITE_STR,'InsertERROR') if($SITE =~ /PBS/i);
  }elsif($ACTIONS =~ /NODE_ENABLED/i){
   &start_or_stop_node("session user-enabled",$nodelist);
  }elsif($ACTIONS =~ /NODE_DISABLED/i){
   &start_or_stop_node("session user-disabled",$nodelist);
  }else{
   print "[ FAILURE ]: The ACTIONS [ $ACTIONS ] is not [NODE_CHECK] or [NODE_ENABLED] or [NODE_DISABLED]\n";
   push @ERROR,"The ACTIONS [ $ACTIONS ] is not [NODE_CHECK] or [NODE_ENABLED] or [NODE_DISABLED]";
  }
 }elsif($ACTIONS =~ /VS_CHECK/i){
  &check_vs_status($_,"InsertERROR") foreach(split /,/,$VS_STR);
 }elsif($ACTIONS =~ /VS_ENABLED/i){
  &start_or_stop_vs("enabled",$VS_STR);
 }elsif($ACTIONS =~ /VS_DISABLED/i){
  &start_or_stop_vs("disabled",$VS_STR);
 }else{
  &others_action();
 }
 
}

##########################################################################################
# ����������
foreach my $do_str(@ACTIONS){
 print "\n\n------------ $do_str RESULT  ------------\n\n";
 &main($do_str);
}

##########################################################################################
# �˳�F5�豸��NA
#$con->cmd('quit\n');
#$con->cmd('exit\n');
$con->disconnect("quit");
$con->logout();
undef $con;

##########################################################################################
# ����ű����
print "\n\n";
if ($#ERROR > -1 ){
 print "[ FAILURE ]: Net-$result_string_forDB-failure !...\n\n";
 #print "\n------------Command Run Log------------\n\n";
 #print $_,"\n\n\n\n" foreach(@LOG);
 exit 1;
}else{
 print "[ SUCCESS ]: Net-$result_string_forDB-success !...\n\n";
}