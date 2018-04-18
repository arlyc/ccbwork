#!/usr/bin/perl
use strict;
use warnings;
use Opsware::NAS::Connect;
###################################################################################
# script name : cmbc_pr_net_check.pl
# editor name : zhaofei 13331187669
# create time : 2015-08-17
# edit   time : 
# info        : 本脚本接收参数如：perl cmbc_pr_net_check.pl $f5_info
######################################################################################

##########################################################################################
## 定义NA属性
our $host = '127.0.0.1';
our $port = '8023';
our $user = 'admin';
our $pass = 'opsware';

##########################################################################################

##########################################################################################
## 脚本参数
our $f5_info = '$f5_info$';
$f5_info =~ s/"//g;
$f5_info =~ s/\s+//g;
#our $f5_info = "5100_vs;;40.56.0.68,40.56.0.69,40.56.0.70,40.56.0.71,40.56.0.72;;40.56.0.82,40.56.0.83,40.56.0.84;;40.0.32.32";
our @info = split /;;/,$f5_info;
our $f5_ip = $info[3];
our $vs_list = $info[0];

##########################################################################################
our @LOG;
our @VS_INFO;
our $con = Opsware::NAS::Connect->new(-user => $user,-pass => $pass,-host =>$host,-port =>$port); #登陆设备
our $active_f5 = "";

##########################################################################################
#登陆NA
if(!$con->login()){
        my $error_info = "[ FAILURE ]: Can't login NA !\n[ FAILURE ]: -failure !...\n\n";
                push @LOG,$error_info;
                exit 1;
}else{
        my $sucess_info = "[ SUCCESS ]: login to [ HP NA ] success \n";
                push @LOG,$sucess_info;
}

##########################################################################################
#检查VS。
#sub check_vs{
#                my $cmd_show = "show ltm virtual neibuzijinguanli_52100_vs\n";
#                my @output = $con->cmd($cmd_show);
#                foreach my $info(@output){
#                                if ($info =~ /^Ltm::Virtual Server:\s+(\w+)/){
#                                push @VS_INFO,$1
#                                }
#                }
#}
sub check_vs{

                        foreach my $vs (split/,/,$vs_list){
                                my $cmd_show = "show ltm virtual $vs";
                                my @output = $con->cmd($cmd_show);
                                #       print @output;  
                                        foreach my $info(@output){
                                                if ($info =~ /^Ltm::Virtual Server:\s+(\w+)/){
                                                push @VS_INFO,$1;
                                #               print $info;
                                }

                                }

                                }
                }

##########################################################################################
#检查active。
sub check_active{
        my $prompt = qr/\#/m;

        foreach my $f5 (split/,/,$f5_ip){
                if(!$con->connect($f5,$prompt)){
                        my $f5_error_info = "[ FAILURE ]: Can't connect [ $f5 ],we will try another f5 device ! \n";
                                                push @LOG,$f5_error_info;
                        next;
                }else{
                        my $f5_sucess_info ="[ SUCCESS ]: connect to F5 [ $f5 ] by [ HP NA ] success \n";
                                                push @LOG,$f5_sucess_info;
                        }
                my $cmd = "show sys failover \n";
                my @output = $con->cmd($cmd);
                my $result = join("\n",@output);

                        if ($result =~ /Failover active/i){
                                my $f5_active =  "[ SUCCESS ]: the F5 [ $f5 ] is active! \n";
                                                                push @LOG,$f5_active;
                                                                &check_vs;
                                                                $active_f5 = $f5;
                               $con->disconnect("quit");
                        }else{
                                my $f5_noactive =  "[ WARNING ]: the F5 [ $f5 ] is not active,we will try another ...\n";
                                                                push @LOG,$f5_noactive;
                                $con->disconnect("quit");
                        }


}
}
&check_active;
#print @VS_INFO;
##########################################################################################
#如果没有active的设备，就不检查vs信息。
if ($active_f5){
        foreach my $vs (split/,/,$vs_list){
                if ($vs ~~ @VS_INFO){
                        my $vs_check_sucess = "[ SUCCESS ]: the [$vs] in [$active_f5] \n";
                        push @LOG,$vs_check_sucess;
                }else{
                        my $vs_check_error = "[ FAILURE ]: the [$vs] not in [$active_f5] \n";
                        push @LOG,$vs_check_error;
                }
        }
}

##########################################################################################
#打印检查结果，结果有FAILURE，则判断为FAILURE。
if (grep /FAILURE/,@LOG){
        print "net_check_failure \n";
        print grep /FAILURE/,@LOG,"\n";

}else{
        print "net_check_sucess \n";
                print grep /SUCCESS/,@LOG,"\n";
                print grep /WARNING/,@LOG,"\n";
}


##########################################################################################
