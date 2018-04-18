#!/usr/bin/perl
use strict;
use warnings;
use Opsware::NAS::Connect;

####################################################################################
# script name   : cmbc_f5_common.pl
# editor name   : wangjianlong 18566756311
# create time   : 2015-05-06
# last edit time : 2015-08-13
# info           : 本脚本接收参数如：perl cmbc_f5_common.pl $ACTIONS  $VS_LIST $SITE
#####################################################################################

###################################   update log #########################################
# 2015-08-13:
#    1、更改推出F5设备的方式 为  $con->disconnect("quit");
#
# 2015-08-07:
#    1、对run_cmd函数中的输出到屏幕上的命令进行特殊符号过滤，防止OO获得NA运行结果为加密编码
# 2015-08-06:
#    1、对sync同步是否成功的判断机制进行了优化更新
#    2、对node节点的操作是否成功的判断机制进行了更新
#    3、新增了对sync同步判断的时长限制，目前设定为10s。
# 2015-07-13: 
#    1、更新了生产环境尝试链接F5设备的方式
#    2、主要针对生产环境：一般由4台F5组成集群，马坡2台鹏博士2台，但只有一台是active，且状态是时刻变化的
#    3、若是大于或多于4台，本脚本同样支持
#    4、更新了sync的成功与否的检查机制，但需要到生产环境实际测试，在生产调用的时候注意观察该命令的返回结果
#     确认判断的条件没有问题
# 2015-06-15:
#    1、对check=true进行模块升级
#    2、若check=true，则对每个操作对象均会首先执行查询操作
#    3、输出格式微调
# 2015-06-09:
#    1、每个变更类函数，新增了判断当前状态是否已经符合将要变更的状态的功能：
#     若是符合即无需再次执行变更；若是不符合，执行变更
#    2、新增了check=true的功能，即脚本运行是否为桌面演练
#    3、优化了脚本整体架构,大大增加了脚本灵活性和可扩展性
#    4、优化了函数定义和调用
#    5、完成sync同步功能测试，但因部署区只有一台F5设备，同步操作实际没有起到作用，将来需要进一步对主备机的情况进行测试
# 2015-05-06:
#    1、开发F5通用脚本，主要实现的功能：VS_CHECK VS_ENABLED VS_DISABLED MEMBER_CHECK POOL_CHECK NODE_CHECK NODE_ENABLED NODE_DISABLED SYNC
#    2、通过了测试环境测试
#    3、同步sync的功能暂时不能测试，需要等待通知   
######################################################################################

##########################################################################################
## 定义NA属性
our ($f5_device_ip,$F5_DEVICE_LIST,$ACTIONS,$SITE,$CHECK,$VS_LIST);
our $host = '127.0.0.1';
our $port = '8023';
our $user = 'admin';
our $pass = 'opsware';
our $sleep_time = 10 ; #该参数定义循环检查同步是否成功的次数，每次休眠一秒，若超过该属性值而且还未判断出同步成功则为失败；

##########################################################################################
# 获得传入脚本的参数
# VS_CHECK VS_ENABLED VS_DISABLED MEMBER_CHECK POOL_CHECK NODE_CHECK NODE_ENABLED NODE_DISABLED SYNC

$ACTIONS = '$ACTIONS$';      #操作码，若是多个中间用英文,隔开
$VS_LIST = '$VS_LIST$';     #所有的F5信息，格式 vs1,vs2,vs3;;mp_ip1,mp_ip2...;;pbs_ip1,pbs_ip2... 
$SITE = '$SITE$';      #告诉脚本此次需要做的操作是在哪个机房，多个用英文,隔开
$CHECK = '$check$';      #check若为true，则表示本次脚本调用为桌面演练  

#$ACTIONS = 'SYNC';
#$SITE = 'MP'; #PBS MP
#$CHECK = 'true'; #true
####$VS_LIST = "pes_14050_vs,pes_14050_vs;;197.3.133.209,197.3.133.209;;197.3.133.238,197.3.133.238";
#$VS_LIST = "NPS_15060_vs,NPS_15070_vs,NPS_15080_vs,NPS_15090_vs,NPS_16000_vs,NPS_17060_vs,NPS_30509_vs,NPS_30544_vs,NPS_30545_vs,NPS_4100_vs,NPS_50000_vs,NPS_5100_vs;;40.56.0.68,40.56.0.69,40.56.0.70,40.56.0.71,40.56.0.72;;40.56.0.82,40.56.0.83,40.56.0.84;;40.0.32.481,40.0.32.428";
#$VS_LIST = "neibuzijinguanli_52100_vs;;40.38.82.11,40.38.82.12;;40.38.82.14;;40.0.32.32,40.0.32.33,40.0.32.40,40.0.32.41";
##########################################################################################
# 其它属性定义
our $ACTION_STR = "VS_CHECK VS_ENABLED VS_DISABLED MEMBER_CHECK POOL_CHECK NODE_CHECK NODE_ENABLED NODE_DISABLED SYNC";
our @LOG;             #存放命令执行过程以及最终结果
our @ERROR;           #存放命令是否正确执行
our @F5_INFO ;        #存放查询到的F5信息

##########################################################################################
# 参数初始化

# 去掉特殊符号
$ACTIONS =~ s/"//g;$ACTIONS =~ s/\s+//g;$VS_LIST =~ s/"//g;$VS_LIST =~ s/\s+//g;

# 分组操作码
our @ACTIONS = split /,/,$ACTIONS;    #若是多个操作码，则进行分组
our $result_string_forDB = join("-",@ACTIONS); #为报告给OO脚本执行结果做准备
our @info = split /;;/,$VS_LIST;      #对输入的信息进行分组操作

# 检查VS_LIST是否符合  “vsname;;马坡node节点;;鹏博士node节点”   的格式
if ($#info ne 3){
 print "[ FAILURE ]: Init F5 info failed from outside, no vsnames or mapo(pengboshi)'s node IP!\n";
 print "   F5 INFO : $VS_LIST \n\n";
 print "[ FAILURE ]: Net-$result_string_forDB-failure !...\n\n"; exit 1;
}
# 检查是否支持 action
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
# 准备工作

# 登陆NA和F5设备
our $con = Opsware::NAS::Connect->new(-user => $user,-pass => $pass,-host =>$host,-port =>$port);
# 判断是否登陆HP NA系统成功
if(!$con->login()){
 print "[ FAILURE ]: Can't login NA !\n[ FAILURE ]: Net-$result_string_forDB-failure !...\n\n"; exit 1;
}else{
 print "[ SUCCESS ]: login to [ HP NA ] success \n";
}

# 判断是否通过HP NA登陆设备成功
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


# 判断是否是桌面演练，若是则输出关键字然后退出脚本，不是则调用主函数继续执行
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
# 定义各类函数

# 定义命令执行函数
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
# 定义vs检查函数
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
# 定义vs启动函数
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
# 定义NODE检查函数
sub check_node_status{
 # 定义insert_error字符串是为了方便启停node进行检查
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
# 定义node启停函数
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
# 定义pool检查函数
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
# 定义member检查函数
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
# 定义同步函数
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
# 定义单个vs信息查询函数
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
#定义多个vs信息查询函数
sub init_get_info{
 $VS_STR =~ s/\s+//g;
 print "[ SUCCESS ]: Begin search the vs info...\n\n";
 print "vsname                    vs info\n";
 &get_info($_) foreach split /,/,$VS_STR;
}
# 定义需要到F5上先获取信息，再进行操作的action函数; ACTION，POOL_CHECK，MEMBER_CHECK
sub others_action{
 &init_get_info();
 our @PBS_SITE_STR = split /,/,$PBS_SITE_STR; #用户输入的鹏博士的node节点分组
 our @MP_SITE_STR = split /,/,$MP_SITE_STR; #用户输入的马坡的node节点分组

 foreach my $SUB_ACTION(@ACTIONS){
  #print "\n------------",$SUB_ACTION," RESULT------------\n\n";
  foreach my $sub_info(@F5_INFO){
   print "\n[ SUCCESS ]: f5 string [ $sub_info ]\n";
   our @node_str; #用户输入的node和设备上的进行匹配，结果存入该数组
   our @sub_info = split /;/,$sub_info; #最全的设备上的信息再分组
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
 
   my %count;our @strs = grep {++$count{$_}<2} @node_str; #去重复
   our $sub_info_dealed = $sub_info[0].";".$sub_info[1].";".join(',',@strs); #最终的需要到设备上执行动作的目标信息 
   #&main($SUB_ACTION,$sub_info_dealed) if ($#ERROR < 0); #若有错误不执行操作
   
   # 根据操作码开始到设备上执行操作
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
# 主函数
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
# 调用主函数
foreach my $do_str(@ACTIONS){
 print "\n\n------------ $do_str RESULT  ------------\n\n";
 &main($do_str);
}

##########################################################################################
# 退出F5设备和NA
#$con->cmd('quit\n');
#$con->cmd('exit\n');
$con->disconnect("quit");
$con->logout();
undef $con;

##########################################################################################
# 输出脚本结果
print "\n\n";
if ($#ERROR > -1 ){
 print "[ FAILURE ]: Net-$result_string_forDB-failure !...\n\n";
 #print "\n------------Command Run Log------------\n\n";
 #print $_,"\n\n\n\n" foreach(@LOG);
 exit 1;
}else{
 print "[ SUCCESS ]: Net-$result_string_forDB-success !...\n\n";
}