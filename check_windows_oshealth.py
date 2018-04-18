import os
import sys
import datetime

exit_invalid_args = 1
exit_other = -1
ERROR = "Error" 
os.environ['TZ'] = 'BST-8'

def write_to_file(line):
    self_file = "check_windows_oshealth.py.log"
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

def get_cpu_usage():
    lines = os.popen("wmic cpu get LoadPercentage /every:60 /repeat:1").readlines()
    counter = 0
    total = 0
    if lines[0].find("LoadPercentage") >= 0:
        for line in lines:
            cpu_num = line.strip()
            if cpu_num.isdigit():
                total = total + int(cpu_num) 
                counter = counter + 1
        return str(total / counter)
    else:
        return ERROR;     

def get_disk_usage():
    result_dict = {"disk_c_free":ERROR, "disk_other_free":ERROR}
    
    lines_c = os.popen("WMIC Path Win32_LogicalDisk where Caption='C:' get FreeSpace,size").readlines()
    if lines_c[0].find("FreeSpace") >= 0:
        line_c_ary = lines_c[1].split()
        disk_c_free = str(int(line_c_ary[0]) * 100 / int(line_c_ary[1]))
        result_dict["disk_c_free"] = disk_c_free
        
    lines_other = os.popen("WMIC Path Win32_LogicalDisk where (Caption!='C:' and DriveType=3) get Freespace,Size").readlines()
    if lines_other[0].find("FreeSpace") >= 0:
        free_other = 0
        total_other = 0
        for line_other in lines_other[1:]:
            line_other_ary = line_other.split()
            if len(line_other_ary)==2:
                free_other = free_other + int(line_other_ary[0].strip())
                total_other = total_other + int(line_other_ary[1].strip())
        disk_other_free = str(free_other * 100 / total_other)
        result_dict["disk_other_free"] = disk_other_free
    elif lines_other[0].strip()=='':
        result_dict["disk_other_free"] = "101"
    return result_dict     

def get_mem_usage():
    lines1 = os.popen("wmic OS get FreePhysicalMemory").readlines()
    free_py_mem = lines1[1]
    lines2 = os.popen("wmic COMPUTERSYSTEM get TotalPhysicalMemory").readlines()
    total_py_mem = lines2[1]
    py_mem_usage = str(int(100 - int(free_py_mem) * 100 * 1000 / int(total_py_mem)))
    result_dict = {"phy_mem_usage":py_mem_usage}
    return result_dict

def get_sync_sent_count():
    lines = os.popen("netstat -an|findstr SYN_SENT").readlines()
    result_dict = {"sync_sent_count":str(len(lines))}
    return result_dict

def get_handle_count():
    lines = os.popen("wmic process GET HandleCount").readlines()
    total = 0
    if lines[0].find("HandleCount") >= 0:
        for line in lines:
            line_count = line.strip()
            if line_count.isdigit():
                total = total + int(line_count)
    result_dict = {"handle_count":str(total)}
    return result_dict

def main():
    lines = []
    cpu = get_cpu_usage()
    lines.append(format_result_line("cpu_usage", cpu))
    dict_all = dict(get_disk_usage().items() + get_mem_usage().items() + get_sync_sent_count().items() + get_handle_count().items())
    for dict_key in dict_all:
        lines.append(format_result_line(dict_key, dict_all[dict_key]))
    for line in lines:
        print line
    write_to_file(os.linesep.join(lines))
    
    
main()

