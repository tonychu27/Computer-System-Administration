#include <iostream>
#include <sys/types.h>
#include <sys/event.h>
#include <sys/stat.h>
#include <sys/time.h>
#include <syslog.h>
#include <unistd.h>
#include <fcntl.h>
#include <pwd.h>
#include <cstring>
#include <cstdlib>
#include <string>
#include <vector>
#include <map>
#include <filesystem>
using namespace std;
namespace fs = filesystem;

const string ROOT_DIR = "/home/sftp/";
const string VIOLATE_DIR = "/home/sftp/hidden/.violated/";

void logViolation(const string& message) {
    openlog("sftp_watchd", LOG_PID | LOG_CONS, LOG_LOCAL6);
    syslog(LOG_INFO, "%s", message.c_str());
    closelog();
}

bool executable(const string& file) {
    struct stat fileState;
    if(stat(file.c_str(), &fileState) < 0) return 0;
    return (fileState.st_mode & S_IXUSR) || (fileState.st_mode & S_IXGRP) || (fileState.st_mode & S_IXOTH);
}

string getUser(const string& filepath) {
    struct stat fileStat;
    if (stat(filepath.c_str(), &fileStat) == 0) {
        struct passwd *pw = getpwuid(fileStat.st_uid);
        if (pw != nullptr) return pw->pw_name;
    }

    return "unknown";
}

void moveFile(const string& file) {
    string dest = VIOLATE_DIR + fs::path(file).filename().string();
    string usr = getUser(file);
    if(file == dest) return;
    fs::copy(file, dest, fs::copy_options::overwrite_existing);
    fs::remove(file);
    logViolation(file + " violate file detected. Uploaded by " + usr + ".");
}

void setup(map<int, string>& fd, int kq) {
    for(const auto &entry: fs::recursive_directory_iterator(ROOT_DIR)) {
        if(fs::is_directory(entry.path())) {
            int dir_fd = open(entry.path().c_str(), O_RDONLY);
            fd[dir_fd] = entry.path();

            struct kevent event;
            EV_SET(&event, dir_fd, EVFILT_VNODE, EV_ADD | EV_ENABLE | EV_CLEAR, NOTE_WRITE | NOTE_EXTEND | NOTE_ATTRIB, 0, nullptr);
            kevent(kq, &event, 1, nullptr, 0, nullptr);
        }
    }
}

void start(map<int, string>& fd, int kq) {
    while (1) {
        struct kevent change;
        EV_SET(&change, 0, 0, 0, 0, 0, nullptr);
        int nev = kevent(kq, nullptr, 0, &change, 1, nullptr);
        if (nev > 0 && (change.filter == EVFILT_VNODE)) {
            auto dirPath = fd[change.ident];
            for(const auto& entry: fs::directory_iterator(dirPath)) {
                if(fs::is_regular_file(entry.path())) {
                    string filepath = entry.path().string();
                    if(executable(filepath) || filepath.substr(18, 5) == "test-") moveFile(filepath);
                }
            }
        }
    }
}

int main() {
    int kq = kqueue();
    map<int, string> fd;
    setup(fd, kq);
    start(fd, kq);

    for(auto &[f, path]: fd) close(f);
    close(kq);
    return 0;
}
