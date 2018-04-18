#!/usr/bin/env python
# -*- coding: utf-8 -*-
"""
  Author: hwx --<wen-xuan.huang@hp.com>
  Purpose: 
  Created: 12/11/2014
"""

import socket
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


def check_server(address, port):
    # Create a TCP socket
    s = socket.socket()
    s.settimeout(3)
    #print "Attempting to connect to %s on port %s" % (address, port)
    try:
        s.connect((address, port))
        s.close()
        #print "Connected to %s on port %s" % (address, port)
        return True
    except socket.error, e:
        #print "Connection to %s on port %s failed: %s" % (address, port, e)
        return False

if __name__ == '__main__':
    test_item = ['127.0.0.1:8080', '99.1.76.195:2222']

    # 设置检查的应用服务器
    check_item = test_item
    if len(check_item) == 0:
        sys.exit()

    false_count = 0
    result = []
    for i in check_item:
        address = i.split(':')[0]
        port = int(i.split(':')[1])
        check = check_server(address, port)
        result.append('%s:%s %s' % (address, port, check))
        if check == False:
            false_count += 1

    if false_count == 0:
        print True
        Loger().write_line('remote_port', 'True')
    else:
        print str(result)
        Loger().write_line('remote_port', str(result))