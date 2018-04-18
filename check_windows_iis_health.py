import os
import urllib2
import sys
import datetime

exit_invalid_args = 1
exit_other = -1
ERROR = "Error" 
os.environ['TZ'] = 'BST-8'

def write_to_file(line):
    self_file = "check_windows_iis_health.py.log"
    log_dir = "c:/usr/local/opsware/sys_audit_log/"
    log_path = os.path.join(log_dir, self_file)
    if not os.path.exists(log_dir):
        os.makedirs(log_dir)        
    output = open(log_path, 'w')
    try:
        output.write(line)
        output.write(os.linesep)
        output.close()
    except Exception, e:
        output.close()
        print "ERROR: write to file failed: " + log_path
        print str(e)
        sys.exit(exit_other)
        
def format_result_line(rule, result):
    utc_now = datetime.datetime.utcnow()
    china_now = utc_now + datetime.timedelta(hours=8)
    now_f = china_now.strftime("%Y-%m-%d %H:%M:%S")
    return "|".join([now_f, rule, result])

        
def find_keyword_by_url(url, keyword):
    try:   
        req = urllib2.Request(url)
        res_data = urllib2.urlopen(req)
        content = res_data.read()
        if content.find(keyword)>=0:
            return True
        else:
            return False
    except Exception, e:
        print str(e)
        return False
    
def main():
    lines = []
    netpay_url = "https://xxx.com"
    netpay_kw = "OK"
    netpay_result = find_keyword_by_url(netpay_url, netpay_kw)
    lines.append(format_result_line("netpay_status", str(netpay_result)))
    
    cdpay_url = "https://xxx.com"
    cdpay_kw = "CDPAY_SERVER_OK"
    cdpay_result = find_keyword_by_url(cdpay_url, cdpay_kw)
    lines.append(format_result_line("cdpay_status", str(cdpay_result)))
    for line in lines:
        print line
    write_to_file(os.linesep.join(lines))
    

main()

