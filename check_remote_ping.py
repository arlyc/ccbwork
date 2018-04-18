#!/usr/bin/env python
# -*- coding: utf-8 -*-
"""
  Author: hwx --<wen-xuan.huang@hp.com>
  Purpose: 
  Created: 12/11/2014
"""

import subprocess
import os
import sys
import datetime

class Loger():
    """
    写日志到本地文件
    使用本class时需先import os, sys, datetime
    如只写入一行文件:
    	Loger().write_line(rule, result)
    如写入多行文件:
    	log = Loger()
    	log.write_line(rule, result)
    	log.write_line(rule, result)
    日志写入的格式如: 2014-12-11 10:52:06|cpu_usage|16
    """
    def __init__(self):
        os.environ['TZ'] = 'BST-8'
        dirname = 'c:\\usr\\local\\opsware\\sys_audit_log'
        filename = os.path.abspath(dirname + os.sep + os.path.basename(__file__) + '.log')
        try:
            if not os.path.exists(dirname):
                os.makedirs(dirname)
            self.file = open(filename, mode='w')
        except:
            print "Open file error: %s" % filename
            sys.exit(-1)

    def write_line(self, rule, result):
        utc_now = datetime.datetime.utcnow()
        china_now = utc_now + datetime.timedelta(hours=8)
        now_f = china_now.strftime("%Y-%m-%d %H:%M:%S")
        try:
            line = "|".join([now_f, rule, result])
            self.file.write(line + os.linesep)
        except:
            print "Write file error: %s" % self.file.name
            sys.exit(-1)

    def __del__(self):
        self.file.flush()
        self.file.close()


def windows_ping(address = '127.0.0.1'):
    command = 'ping.exe -n 2 -w 500 %s' % address
    p = subprocess.Popen(command, stdout=subprocess.PIPE, stderr=subprocess.STDOUT, shell=True)
    if p.wait() == 0:
        return True
    else:
        return False

if __name__ == '__main__':
    test_item = ['129.0.0.1', '99.1.76.195']

    # 设置检查的应用服务器
    check_item = test_item
    if len(check_item) == 0:
        sys.exit()

    false_count = 0
    result = []
    for i in check_item:
        check = windows_ping(i)
        result.append('%s %s' % (i, check))
        if check == False:
            false_count += 1

    if false_count == 0:
        print True
        Loger().write_line('ping', 'True')
    else:
        print str(result)
        Loger().write_line('ping', str(result))