;; please see copyright notice in ./COPYING

;;; 3.2  I/O

(define binary-input 'internal-binary-input-symbol)
(define textual-input 'internal-textual-input-symbol)
(define binary-output 'internal-binary-ouput-symbol)
(define textual-output 'internal-textual-output-symbol)
(define binary-input/output 'internal-binary-input/output-symbol)
;; None of these are implemented or even checked for as of yet:
(define buffer-none 'unimplemented-buffer-none-symbol)
(define buffer-block 'unimplemented-buffer-block-symbol)
(define buffer-line 'unimplemented-buffer-line-symbol)

(define (fd->textual-input-port the-fd)
  (%file_descriptor_to_port the-fd #t #f))

(define (fd->binary-input-port the-fd)
  (%file_descriptor_to_port the-fd #t #t))

(define (fd->textual-output-port the-fd)
  (%file_descriptor_to_port the-fd #f #f))

(define (fd->binary-output-port the-fd)
  (%file_descriptor_to_port the-fd #f #t))

(define (open-file* fname flags permission-bits)
    (let ((fd (retry-if-EINTR (lambda () (%open fname flags permission-bits)))))
      (if (equal? -1 fd)
          (errno-error (errno) 'open-file 'open fname flags permission-bits)
          fd)))

(define (open-file fname port-type flags . o)
  (let-optionals o ((permission-bits #o666))
    (if (not (string? fname))
        (sanity-check-error "fname must be a string" 'open-file fname))
    (if (not (symbol? port-type))
        (sanity-check-error "invalid port-type" 'open-file port-type))
    (if (not (fixnum? flags))
        (sanity-check-error "flags must be a fixnum" 'open-file flags))
    (if (not (fixnum? permission-bits))
        (sanity-check-error "permission-bits must be a fixnum" 'open-file permission-bits))
    (cond ((eq? port-type textual-input)
           (fd->textual-input-port (open-file* fname (bitwise-ior open/read flags) permission-bits)))
          ((eq? port-type binary-input)
           (fd->binary-input-port (open-file* fname (bitwise-ior open/read flags) permission-bits)))
          ((eq? port-type textual-output)
           (fd->textual-output-port (open-file* fname (bitwise-ior open/write flags) permission-bits)))
          ((eq? port-type binary-output)
           (fd->binary-output-port (open-file* fname (bitwise-ior open/write flags) permission-bits)))
          ((eq? port-type binary-input/output)
           (sanity-check-error "binary-input/output is not implemented" 'open-file))
          (else (sanity-check-error "unknown port-type" 'open-file port-type)))))

(define (fd->port the-fd port-type)
  (if (not (exact-integer? the-fd))
      (sanity-check-error "argument must be an exact integer" 'fd->port the-fd))
  (if (not (symbol? port-type))
      (sanity-check-error "invalid port-type" 'fd->port port-type))
  (cond ((eq? port-type textual-input)
         (fd->textual-input-port the-fd))
        ((eq? port-type binary-input)
         (fd->binary-input-port the-fd))
        ((eq? port-type textual-output)
         (fd->textual-output-port the-fd))
        ((eq? port-type binary-output)
         (fd->binary-output-port the-fd))
        ((eq? port-type binary-input/output)
         (sanity-check-error "binary-input/output is not implemented" 'open-file))
        (else (sanity-check-error "unknown port-type" 'open-file port-type))))


;;; 3.3  File system

(define (create-directory fname . o)
  (if (not (string? fname))
        (sanity-check-error "fname must be a string" 'create-directory fname))
  (let-optionals o ((permission-bits #o775))
    (if (not (exact-integer? permission-bits))
        (sanity-check-error "permission-bits must be an exact integer" 'create-directory permission-bits))
    (if (not (%mkdir fname permission-bits))
        (errno-error (errno) 'create-directory 'mkdir fname))))

(define (create-fifo fname . o)
  (if (not (string? fname))
        (sanity-check-error "fname must be a string" 'create-fifo fname))
  (let-optionals o ((permission-bits #o664))
    (if (not (exact-integer? permission-bits))
        (sanity-check-error "permission-bits must be an exact integer" 'create-fifo permission-bits))
    (if (not (%mkfifo fname permission-bits))
        (errno-error (errno) 'create-fifo 'mkfifo fname))))

(define (create-hard-link oldname newname)
  (if (not (string? oldname))
        (sanity-check-error "first argument must be a string" 'create-hard-link oldname))
  (if (not (string? newname))
        (sanity-check-error "second argument must be a string" 'create-hard-link newname))
    (if (not (%link oldname newname))
        (errno-error (errno) 'create-hard-link 'link oldname newname)))

(define (create-symlink oldname newname)
  (if (not (string? oldname))
        (sanity-check-error "first argument must be a string" 'create-symlink oldname))
  (if (not (string? newname))
        (sanity-check-error "second argument must be a string" 'create-symlink newname))
    (if (not (%symlink oldname newname))
        (errno-error (errno) 'create-symlink 'symlink oldname newname)))

(cond-expand
  (windows
    (define (read-symlink fname) #f))
  (else
    (define (read-symlink fname)
      (if (not (string? fname))
          (sanity-check-error "fname must be a string" 'read-symlink fname))
      (let* ((buf (make-string (+ 1 PATH_MAX)))
             (res (%readlink fname buf PATH_MAX)))
        (if (positive? res)
            (substring buf 0 res)
            (errno-error (errno) 'read-symlink 'readlink fname))))))

(define (rename-file oldname newname)
  (if (not (string? oldname))
        (sanity-check-error "first argument must be a string" 'rename-file oldname))
  (if (not (string? newname))
        (sanity-check-error "second argument must be a string" 'rename-file newname))
  (if (not (%rename oldname newname))
      (errno-error (errno) 'rename-file 'rename oldname newname)))

(define (delete-directory fname)
  (if (not (string? fname))
        (sanity-check-error "fname must be a string" 'delete-directory fname))
  (if (not (%rmdir fname))
      (errno-error (errno) 'delete-directory 'rmdir fname)))

(define (set-file-mode fname permission-bits)
  (if (not (string? fname))
        (sanity-check-error "fname must be a string" 'set-file-mode fname))
  (if (not (exact-integer? permission-bits))
        (sanity-check-error "permission-bits must be an exact integer" 'set-file-mode permission-bits))
  (if (not (retry-if-EINTR (lambda () (%chmod fname permission-bits))))
      (errno-error (errno) 'set-file-mode 'chmod fname permission-bits)))

(define owner/unchanged -1)
(define group/unchanged -1)

(define (set-file-owner fname uid gid)
  (if (not (string? fname))
      (sanity-check-error "fname must be a string" 'set-file-owner fname))
  (if (not (exact-integer? uid))
      (sanity-check-error "uid must be an exact integer" 'set-file-owner uid))
  (if (not (exact-integer? gid))
      (sanity-check-error "gid must be an exact integer" 'set-file-owner gid))
  (if (not (retry-if-EINTR (lambda () (%chown fname uid gid))))
      (errno-error (errno) 'set-file-owner 'chown fname uid gid)))

;; For the purposes of the SRFI 170 API, the time-type as used here is
;; irrelevant ~~~ but this could be confusing
(define time/now (make-time time-utc -1 utimens/utime_now))
(define time/unchanged (make-time time-utc -1 utimens/utime_omit))

(define set-file-times
  (case-lambda
   ((fname) (set-file-times* fname time/now time/now))
   ((fname atime mtime) (set-file-times* fname atime mtime))))

(define (set-file-times* fname atime mtime)
  (if (or (not (time? atime)) (not (time? mtime)))
      (sanity-check-error "atime and mtime must be SRFI 19 times" 'set-file-times* fname atime mtime))
  (if (or (not (eq? time-utc (time-type atime))) (not (eq? time-utc (time-type mtime))))
      (sanity-check-error "atime and mtime must have a time-type of time-utc" 'set-file-times* fname atime mtime))
  (if (not (%utimensat utimens/at_fdcwd
                       fname
                       ;; This underlying representation will do for now,
                       ;; a cons cell is very simple
                       (cons (time-second atime) (time-nanosecond atime))
                       (cons (time-second mtime) (time-nanosecond mtime))
                       0))
      (errno-error (errno) 'set-file-times 'utimensat fname atime mtime)))

(define (truncate-file fname-or-port len)
  (if (not (exact-integer? len))
        (sanity-check-error "second argument must be an exact integer" 'truncate-file len))
  (cond ((string? fname-or-port)
         (if (not (retry-if-EINTR (lambda () (%truncate fname-or-port len))))
             (errno-error (errno) 'truncate-file 'truncate fname-or-port len)))
        ((port? fname-or-port)
         (if (not (retry-if-EINTR (lambda () (%ftruncate (port-fileno fname-or-port) len))))
             (errno-error (errno) 'truncate-file 'ftruncate fname-or-port len)))
        (else (sanity-check-error "first argument must be a file name or a port" 'truncate-file fname-or-port len))))

(cond-expand
  (windows
   (define-record-type File-Info
       (make-file-info device inode mode nlinks uid gid rdev sizeatime mtime ctime)
       file-info?
     (device file-info:device)
     (inode file-info:inode)
     (mode file-info:mode)
     (nlinks file-info:nlinks)
     (uid file-info:uid)
     (gid file-info:gid)
     (rdev file-info:rdev)
     (size file-info:size)
     (atime file-info:atime)
     (mtime file-info:mtime)
     (ctime file-info:ctime)))
  (else
   (define-record-type File-Info
       (make-file-info device inode mode nlinks uid gid rdev size blksize blocks atime mtime ctime)
       file-info?
     (device file-info:device)
     (inode file-info:inode)
     (mode file-info:mode)
     (nlinks file-info:nlinks)
     (uid file-info:uid)
     (gid file-info:gid)
     (rdev file-info:rdev)
     (size file-info:size)
     (blksize file-info:blksize)
     (blocks file-info:blocks)
     (atime file-info:atime)
     (mtime file-info:mtime)
     (ctime file-info:ctime))))

(define (file-info fname-or-port follow?)
  (let ((file-stat
         (cond ((string? fname-or-port)
                (let ((the-file-info (if follow?
                                         (%stat fname-or-port)
                                         (%lstat fname-or-port))))
                  (if the-file-info
                      the-file-info
                      (errno-error (errno)
                                   'file-info
                                   (if follow?
                                       'stat
                                       'lstat)
                                   fname-or-port))))
               ((port? fname-or-port)
                (let ((the-file-info (%fstat (port-fileno fname-or-port))))
                  (if the-file-info
                      the-file-info
                      (errno-error (errno) 'file-info 'fstat fname-or-port follow?))))
               (else (sanity-check-error "first argument must be a string or port" 'file-info fname-or-port)))))
    (if (not file-stat)
        (errno-error (errno)
                     'file-info
                     (if (string? fname-or-port)
                            (if follow?
                                'stat
                                'lstat)
                            'fname-or-port)
                     fname-or-port
                     follow?))
    (make-file-info
     (stat:dev file-stat)
     (stat:ino file-stat)
     (stat:mode file-stat)
     (stat:nlinks file-stat)
     (stat:uid file-stat)
     (stat:gid file-stat)
     (stat:rdev file-stat)
     (stat:size file-stat)
     (stat:blksize file-stat)
     (stat:blocks file-stat)
     (make-time time-utc (posix-timespec:seconds (stat:atime file-stat)) (posix-timespec:nanoseconds (stat:atime file-stat)))
     (make-time time-utc (posix-timespec:seconds (stat:mtime file-stat)) (posix-timespec:nanoseconds (stat:mtime file-stat)))
     (make-time time-utc (posix-timespec:seconds (stat:ctime file-stat)) (posix-timespec:nanoseconds (stat:ctime file-stat))))))

(define (file-info-directory? file-info-record)
  (S_ISDIR (file-info:mode file-info-record)))

(define (file-info-fifo? file-info-record)
  (S_ISFIFO (file-info:mode file-info-record)))

(define (file-info-symlink? file-info-record)
  (S_ISLNK (file-info:mode file-info-record)))

(define (file-info-regular? file-info-record)
  (S_ISREG (file-info:mode file-info-record)))

(define (file-info-socket? file-info-record)
  (S_ISSOCK (file-info:mode file-info-record)))

(define (file-info-device? file-info-record)
  (or (S_ISBLK (file-info:mode file-info-record))
      (S_ISCHR (file-info:mode file-info-record))))

(define-record-type Directory-Object
    (make-directory-object the-DIR is-open? dot-files?)
    directory-object?
  (the-DIR directory-object-get-DIR)
  (is-open? directory-object-is-open? set-directory-object-is-open)
  (dot-files? directory-object-dot-files?))

;;> The fundamental directory iterator.  Applies \var{kons} to
;;> each filename in directory \var{dir} and the result of the
;;> previous application, beginning with \var{knil}.  With
;;> \var{kons} as \scheme{cons} and \var{knil} as \scheme{'()},
;;> equivalent to \scheme{directory-files}.

(define (directory-fold dir kons knil . o)
  (let-optionals o ((dot-files? #f))
    (let ((do (open-directory dir dot-files?)))
      (let lp ((res knil))
        (let ((file (read-directory do)))
          (if (not (eof-object? file))
              (lp (kons file res))
              (begin (close-directory do) res)))))))

;;> Returns a list of the files in \var{dir} in an unspecified
;;> order.

(define (directory-files dir . o)
  (let-optionals o ((dot-files? #f))
    (directory-fold dir cons '() dot-files?)))

(define make-directory-files-generator
  (case-lambda
    ((dir dot-files?) (make-directory-files-generator* dir dot-files?))
    ((dir) (make-directory-files-generator* dir #f))))

;; Use this commented out version if your dir-obj AKA directory object
;; abstraction doesn't keep track of when it has been closed:

#|
(define (make-directory-files-generator* dir dot-files?)
  (let ((dir-obj (open-directory dir dot-files?))
        (eof (eof-object))
        (done #f))
    (lambda ()
      (if done eof
        (let ((f (read-directory dir-obj)))
          (when (eq? f eof)
            (close-directory dir-obj)
            (set! done #t))
          f)))))
|#

(define (make-directory-files-generator* dir dot-files?)
  (let ((dir-obj (open-directory dir dot-files?))
        (eof (eof-object)))
    (lambda ()
      (if (not (directory-object-is-open? dir-obj))
          eof
          (let ((f (read-directory dir-obj)))
            (if (eq? f eof) (close-directory dir-obj))
            f)))))

(define (open-directory dir . o)
  (if (not (string? dir))
        (sanity-check-error "dir must be a string" 'open-directory dir))
  (let-optionals o ((dot-files? #f))
    (let ((ret (%opendir dir)))
      (if ret
          (make-directory-object ret #t dot-files?)
          (errno-error (errno) 'open-directory 'opendir dir)))))

(define (read-directory-raise-error dirobj)
  (set-errno 0)
  (let* ((de (%readdir (directory-object-get-DIR dirobj)))
         (e (errno)))
    (if (equal? 0 e)
        de
        (errno-error e 'read-directory 'readdir dirobj))))

(define (read-directory dirobj)
  (if (not (directory-object? dirobj))
      (sanity-check-error "argument must be a director object created by open-directory" 'read-directory dirobj))
  (if (not (directory-object-is-open? dirobj))
      (sanity-check-error "argument must be a directory object not already closed" 'read-directory dirobj))
  (let ((dot-files? (directory-object-dot-files? dirobj)))
    (let loop ()
      (let ((de (read-directory-raise-error dirobj)))
        (if (not de)
            (eof-object)
            (let ((name (dirent-name de)))
              (if (not (and (string? name)
                            (or (equal? "." name)
                                (equal? ".." name)
                                (and (not dot-files?) (equal? #\. (string-ref name 0))))))
                  name
                  (loop))))))))

(define (close-directory directory-object)
  (if (not (directory-object? directory-object))
      (sanity-check-error "argument must be a director object created by open-directory" 'close-directory directory-object))
  ;; this flag, this check, is because the special finalizer stub c function for %closedir does nothing with errno
  (if (not (directory-object-is-open? directory-object))
      (sanity-check-error "argument must be a directory object not already closed" 'close-directory directory-object))
      (set-directory-object-is-open directory-object #f)
      ;; does not dirobj any error stuff, see 170.stub
      (%closedir (directory-object-get-DIR directory-object)))

(define (real-path the-starting-path)
  (if (not (string? the-starting-path))
      (sanity-check-error "argument must be a string" 'real-path the-starting-path))
  (let ((the-real-path (%realpath the-starting-path)))
    (if the-real-path
        the-real-path
        (errno-error (errno) 'real-path 'realpath the-starting-path))))

(define (free-space fname-or-port)
    (let ((the-statvfs (cond ((string? fname-or-port)
                              (retry-if-EINTR (lambda () (%statvfs fname-or-port))))
                             ((port? fname-or-port)
                              (let ((the-fd (port-fileno fname-or-port)))
                                (if (not the-fd)
                                    (sanity-check-error "port must have a file descriptor associated with it" 'fstatvfs fname-or-port)
                                    (retry-if-EINTR (lambda () (%fstatvfs the-fd))))))
                             (else (sanity-check-error "argument must be a file name or a port" 'fstatvfs fname-or-port)))))
      (if (not the-statvfs)
          (if (string? fname-or-port)
              (errno-error (errno) 'free-space 'statvfs fname-or-port)
              (errno-error (errno) 'file-file 'fstatvfs fname-or-port)))
      (*
       (fs:frsize the-statvfs)
       (fs:bavail the-statvfs))))

(define the-character-set "ABCDEFGHIJKLMNOPQURTUVWXYZ0123456789")

(define the-character-set-length (string-length the-character-set))

(define (get-random-character) (string-ref the-character-set (random-integer the-character-set-length)))

(define (suffix-string)
  (string (get-random-character) (get-random-character) (get-random-character)
          (get-random-character) (get-random-character) (get-random-character)
          (get-random-character) (get-random-character) (get-random-character)))

(define temp-file-prefix
  (make-parameter (let ((the-env-var (get-environment-variable "TMPDIR")))
                    (if the-env-var
                        (string-append the-env-var "/" (number->string (pid)))
                        (string-append "/tmp/" (number->string (pid)))))))

(define (create-temp-file . o)
  (let-optionals o ((prefix (temp-file-prefix)))
    (let loop ()
      (let ((the-filename (string-append prefix "." (suffix-string))))
        (if (file-exists? the-filename)
            (loop)
            (let ((the-fileno (open the-filename (bitwise-ior open/write open/create open/exclusive) #o600)))
              (if (not the-fileno)
                  ;; ~~~~ adding the filename is not in the specs, but necessary for sane debugging
                  (sanity-check-error "failed to open a file name" 'create-temp-file prefix the-filename))
              (retry-if-EINTR (lambda () (%close (%fileno-to-fd the-fileno))))
              the-filename))))))

#|
;; Following copied from scsh 0.7 scheme/temp-file.scm:

(define (temp-file-iterate maker . maybe-template)
  (let ((template (:optional maybe-template (fluid *temp-file-template*))))
    (let loop ((i 0))
      (if (> i 1000) (error "Can't create temp-file")
          (let ((fname (format #f template (number->string i))))
            (receive retvals (with-errno-handler
                               ((errno data)
                                ((exist acces) #f))
                               (maker fname))
              (if (car retvals) (apply values retvals)
                  (loop (+ i 1)))))))))


;; Following 3 defines copied from scsh 0.7 scheme/scsh-condition.scm
;; see e.g. scheme48-1.9.2 for things like os-error?

(define (with-errno-handler* handler thunk)
  (with-exception-handler
    (lambda (condition)
      (if (os-error? condition)
          (handler (os-error-code condition)
                   (list (condition-message condition)
                         (condition-who condition)
                         (condition-irritants condition)))
          (raise condition)))
    thunk))

(define-syntax weh-cond
  (syntax-rules (else)
    ((weh-cond () ((cond-condition cond-body) ...) error-number return)
     (cond (cond-condition cond-body) ...))
    ((weh-cond (((errno-name ...) clause-body ...) . other-clauses) (cond-clause ...) error-number return)
     (weh-cond other-clauses
               (cond-clause ... ((or (errno=? (errno errno-name) (integer->errno error-number)) ...)
                                 (call-with-values (lambda () clause-body ...) return)))
               error-number return))
    ((weh-cond ((else clause-body ...) . other-clauses) (cond-clause ...) error-number return)
     (weh-cond other-clauses
               (cond-clause ... (else (call-with-values (lambda () clause-body ...) return)))
               error-number return))))

(define-syntax with-errno-handler
  (syntax-rules ()
    ((with-errno-handler
      ((err data)
       (clause-condition clause-body ...) ...)
      body ...)
     (call-with-current-continuation
      (lambda (return)
        (with-errno-handler*
         (lambda (err data)
           (weh-cond ((clause-condition clause-body ...) ...) () err return))
         (lambda () body ...)))))))


;; Finishing the following is left as an exercise for the reader....

;; Seems to be mostly correct, the with-errno-handler bit as the only
;; part definitately not working, and not trivial, see above

(define (call-with-temporary-filename maker . o)
  (let-optionals o ((the-prefix (temp-file-prefix)))
    (let loop ((i 0))
      (if (> i 1000) (sanity-check-error "exceeded maximum number of tries" 'call-with-temporary-filename maker the-prefix) ~~~~ maybe a better errno (for now)?
          (let ((fname (string-append the-prefix "." (number->string i))))
            (receive retvals (with-errno-handler ;; ~~~~ "THEN A MIRACLE OCCURS..."
                               ((errno data)
                                ((EEXIST EACCES) #f))
                               (maker fname))
              (if (car retvals) (apply values retvals) ;; ~~~~ don't understand the use of values at all
                  (loop (+ i 1)))))))))
|#


;;; 3.5  Process state

(define (umask)
  (let ((current-umask (%umask #o777)))
    (%umask current-umask)
    current-umask))

(define (set-umask! perms)
  (if (not (exact-integer? perms))
        (sanity-check-error "perms must be an exact integer" 'set-umask! perms))
  (%umask perms))

(define (current-directory)
  (let ((dir (%getcwd)))
    (if (not dir)
      (errno-error (errno) 'current-directory 'getcwd)
      dir)))

(define (set-current-directory! fname)
  (if (not (string? fname))
      (sanity-check-error "fname must be a string" 'set-current-directory! fname))
  (if (not (%chdir fname))
      (errno-error (errno) 'set-current-directory 'chdir fname)))

;; pid, parent-pid, and process-group direct from stub, they can't error

(define (nice . o)
  (let-optionals o ((delta 1))
    (if (not (exact-integer? delta))
        (sanity-check-error "delta must be an exact integer" 'nice delta))
    (set-errno 0)
    (let ((ret (%nice delta)))
      (if (and (equal? -1 ret) (not (equal? 0 (errno))))
          (errno-error (errno) 'nice 'nice delta))
      ret)))

(define (user-supplementary-gids)
  (let* ((ret (%getgroups))
         (i (car ret)))
    (if (equal? -1 i)
        (errno-error (errno) 'user-supplementary-gids 'getgroups))
    (take (cadr ret) i))) ;; immutable list


;;; 3.6  User and group database access

(define-record-type User-Info
    (make-user-info name uid full-name parsed-full-name gid home-dir shell)
    user-info?
  (name user-info:name)
  (uid user-info:uid)
  (full-name user-info:full-name)
  (parsed-full-name user-info:parsed-full-name)
  (gid user-info:gid)
  (home-dir user-info:home-dir)
  (shell user-info:shell))

(define (user-info user)
  (set-errno 0)
  (let ((ui (cond ((string? user) (retry-if-EINTR (lambda () (%getpwnam user))))
                  ((exact-integer? user) (retry-if-EINTR (lambda () (%getpwuid user))))
                  (else (sanity-check-error "user must be a string or exact integer" 'user-info user)))))

    (if (not ui)
        (if (equal? 0 (errno))
            #f
            (errno-error (errno)
                         'user-info
                         (if (string? user)
                             'getpwnam
                             'getpwuid)
                         user))
        (make-user-info (passwd:name ui)
                        (passwd:uid ui)
                        (passwd:gecos ui)
                        (parse-gecos (passwd:gecos ui) (passwd:name ui))
                        (passwd:gid ui)
                        (passwd:dir ui)
                        (passwd:shell ui)))))

(define-record-type Group-Info
    (make-group-info name gid)
    group-info?
  (name group-info:name)
  (gid group-info:gid))

(define (group-info group)
  (set-errno 0)
  (let ((gi (cond ((string? group) (retry-if-EINTR (lambda () (%getgrnam group))))
                  ((exact-integer? group) (retry-if-EINTR (lambda () (%getgrgid group))))
                  (else (sanity-check-error "group must be a string or exact integer" 'group-info group)))))

    (if (not gi)
        (if (equal? 0 (errno))
            #f
            (errno-error
             (errno)
             'group-info
             (if (string? group)
                 'getgrnam
                 'getgrdid)
             group))
        (make-group-info (group:name gi)
                         (group:gid gi)))))


;;; 3.10  Time

(define (posix-time)
  (let ((t (%clock_gettime time-utc)))
    (if (not t)
        (errno-error (errno) 'posix-time 'clock_gettime)
        (make-time time-utc (posix-timespec:seconds t) (posix-timespec:nanoseconds t)))))

(define (monotonic-time)
  (let ((t (%clock_gettime time-monotonic)))
    (if (not t)
        (errno-error (errno) 'monotonic-time 'clock_gettime)
        (make-time time-monotonic (posix-timespec:seconds t) (posix-timespec:nanoseconds t)))))


;;; 3.11  Environment variables

(define (set-environment-variable! name value)
  (if (not (string? name))
        (sanity-check-error "name must be a string" 'set-environment-variable! name))
  (if (not (string? value))
        (sanity-check-error "value must be a string" 'set-environment-variable! value))
  (if (not (%setenv name value 1))
      (errno-error (errno) 'set-environment-variable! 'setenv name value)))

(define (delete-environment-variable! name)
  (if (not (string? name))
        (sanity-check-error "name must be a string" 'delete-environment-variable! name))
  (if (not (%unsetenv name))
      (errno-error (errno) 'delete-environment-variable! 'unsetenv name)))


;;; 3.12  Terminal device control

(define (terminal? the-arg)
  (let ((the-fd (if (port? the-arg)
                    (port-fileno the-arg)
                    (sanity-check-error "argument must be a port" 'terminal? the-arg))))
    (if (eq? #f the-fd)
        #f
        (if (< the-fd 0)
            (sanity-check-error "file descriptor for port is less than zero" 'terminal? the-arg)
            (begin
              (set-errno 0)
              (let ((ret (%isatty the-fd)))
                (if (equal? 1 ret)
                    #t
                    (if (or (not (equal? 0 ret))
                            (not (equal? ENOTTY (errno))))
                        (errno-error (errno) 'terminal? 'isatty the-fd)
                        #f))))))))

#|
;; All terminal procedures except for terminal? will be moved to a new
;; SRFI; this working code is left here for it.

(define (terminal-file-name the-port)
  (if (not (port? the-port))
      (sanity-check-error "argument must be a port" 'terminal-file-name the-port))
  (let ((the-fd (port-fd the-port)))
    (if (not the-fd)
        (sanity-check-error "port must have a file descriptor associated with it" 'terminal-file-name the-port))
    (let ((the-file-name (%ttyname_r the-fd)))
      (if (not the-file-name)
          (errno-error (errno) 'terminal-file-name 'ttyname_r the-port))
      the-file-name)))

;; ~~~~ all prefactory with- and without- errno-errors need a more
;;      specific error indicator, that's why they're not combined

(define (with-raw-mode input-port output-port min time proc)
  (if (not (and (port? input-port) (port? output-port)))
      (sanity-check-error "first two arguments must ports" 'with-raw-mode input-port output-port min time proc))
  (if (not (and (terminal? input-port) (terminal? output-port)))
      (sanity-check-error "first two argument must be a terminal port" 'with-raw-mode input-port output-port min time proc))
  (if (not (and (input-port? input-port) (output-port? output-port)))
      (sanity-check-error "first two arguments must be an input and output ports, respectively" 'with-raw-mode input-port output-port min time proc))
  (if (not (exact-integer? min))
      (sanity-check-error "third argument must be an exact integer" 'with-raw-mode input-port output-port min time proc))
  (if (not (exact-integer? time))
      (sanity-check-error "fourth argument must be an exact integer" 'with-raw-mode input-port output-port min time proc))

  (let* ((initial-input-termios (%tcgetattr input-port))
         (initial-output-termios (%tcgetattr output-port))
         (new-input-termios (%tcgetattr input-port)) ;; ~~~~ because of tagging, how to copy is not obvious
         (new-output-termios (%tcgetattr output-port)) ;; ~~~~ because of tagging, how to copy is not obvious
         (reset-terminal (lambda ()
                           (let ((input-return (retry-if-EINTR (lambda () (%tcsetattr input-port TCSAFLUSH initial-input-termios))))) ;; still try resetting output
                             (if (not (and (retry-if-EINTR (lambda () (%tcsetattr output-port TCSAFLUSH initial-output-termios))) input-return))
                                 (errno-error (errno) 'with-raw-mode 'tcsetattr input-port output-port min time proc))))) ;; might as well exit the procedure
         ;; ~~~~~~~~ set all for *both* ports???
         (the-lflags (bitwise-ior ECHO ICANON IEXTEN ISIG))
         (the-iflags (bitwise-ior BRKINT ICRNL INPCK ISTRIP IXON))
         (the-and-cflags (bitwise-ior CSIZE PARENB))
         (the-ior-cflags CS8)
         (the-oflags OPOST))

    (if (or (not initial-input-termios) (not new-input-termios) (not initial-output-termios) (not new-output-termios))
        (sanity-check-error "failure to get or set termios data" 'with-raw-mode input-port output-port min time proc))

    (term-attrs-lflag-set! new-input-termios
                           (bitwise-and (term-attrs-lflag new-input-termios) (bitwise-not the-lflags)))
    (term-attrs-iflag-set! new-input-termios
                           (bitwise-and (term-attrs-iflag new-input-termios) (bitwise-not the-iflags)))
    (term-attrs-cflag-set! new-input-termios
                           (bitwise-and (term-attrs-cflag new-input-termios) (bitwise-not the-and-cflags)))
    (term-attrs-cflag-set! new-input-termios
                           (bitwise-ior (term-attrs-cflag new-input-termios) the-ior-cflags))
    (term-attrs-oflag-set! new-input-termios
                           (bitwise-and (term-attrs-oflag new-input-termios) (bitwise-not the-oflags)))
    (term-attrs-cc-element-set! new-input-termios min VMIN) ;; ~~~~ ought to transpose array index and value to put in it
    (term-attrs-cc-element-set! new-input-termios time VTIME) ;; ~~~~ ought to transpose array index and value to put in it

    (term-attrs-lflag-set! new-output-termios
                           (bitwise-and (term-attrs-lflag new-output-termios) (bitwise-not the-lflags)))
    (term-attrs-iflag-set! new-output-termios
                           (bitwise-and (term-attrs-iflag new-output-termios) (bitwise-not the-iflags)))
    (term-attrs-cflag-set! new-output-termios
                           (bitwise-and (term-attrs-cflag new-output-termios) (bitwise-not the-and-cflags)))
    (term-attrs-cflag-set! new-output-termios
                           (bitwise-ior (term-attrs-cflag new-output-termios) the-ior-cflags))
    (term-attrs-oflag-set! new-output-termios
                           (bitwise-and (term-attrs-oflag new-output-termios) (bitwise-not the-oflags)))
    (dynamic-wind
        (lambda ()      ;; set output port first since input port is the same + VMIN and VTIME, we're probably doing duplicate tcsetattrs at the OS level
          (if (not (and (retry-if-EINTR (lambda () (%tcsetattr output-port TCSAFLUSH new-output-termios)))
                        (retry-if-EINTR (lambda () (%tcsetattr input-port TCSAFLUSH new-input-termios)))))
              (errno-error (errno) 'with-raw-mode 'tcsetattr input-port output-port min time proc)

              ;; For historical reasons, tcsetattr returns 0 if *any*
              ;; of the attribute changes took, so we must check to
              ;; see if all have been set
              (let ((real-new-input-termios (%tcgetattr input-port))
                    (real-new-output-termios (%tcgetattr output-port)))
                (if (not (and real-new-input-termios real-new-output-termios))
                    (begin (reset-terminal)
                           (errno-error (errno) 'with-raw-mode 'tcsetattr input-port output-port min time proc))
                    (if (not (and (equal? (term-attrs-lflag new-input-termios) (term-attrs-lflag real-new-input-termios))
                                  (equal? (term-attrs-iflag new-input-termios) (term-attrs-iflag real-new-input-termios))
                                  (equal? (term-attrs-cflag new-input-termios) (term-attrs-cflag real-new-input-termios))
                                  (equal? (term-attrs-oflag new-input-termios) (term-attrs-oflag real-new-input-termios))
                                  (equal? min (term-attrs-cc-element real-new-input-termios VMIN))
                                  (equal? time (term-attrs-cc-element real-new-input-termios VTIME))

                                  (equal? (term-attrs-lflag new-output-termios) (term-attrs-lflag real-new-output-termios))
                                  (equal? (term-attrs-iflag new-output-termios) (term-attrs-iflag real-new-output-termios))
                                  (equal? (term-attrs-cflag new-output-termios) (term-attrs-cflag real-new-output-termios))
                                  (equal? (term-attrs-oflag new-output-termios) (term-attrs-oflag real-new-output-termios))))
                        (begin (reset-terminal)
                               (sanity-check-error "a termios update failed" 'with-raw-mode input-port output-port min time proc)))))))
        (lambda () (proc input-port output-port))
        (lambda ()
          (reset-terminal)))))

(define (with-rare-mode input-port output-port proc)
  (if (not (and (port? input-port) (port? output-port)))
      (sanity-check-error "first two arguments must be ports" 'with-rare-mode input-port output-port proc))
  (if (not (and (terminal? input-port) (terminal? output-port)))
      (sanity-check-error "first two arguments must be a terminal ports" 'with-rare-mode input-port output-port proc))
  (if (not (and (input-port? input-port) (output-port? output-port)))
      (sanity-check-error "first two arguments must be an input and output ports, respectively" 'with-rare-mode input-port output-port proc))

  (let* ((initial-input-termios (%tcgetattr input-port))
         (initial-output-termios (%tcgetattr output-port))
         (new-input-termios (%tcgetattr input-port)) ;; ~~~~ because of tagging, how to copy is not obvious
         (new-output-termios (%tcgetattr output-port)) ;; ~~~~ because of tagging, how to copy is not obvious
         (reset-terminal (lambda ()
                           (let ((input-return (retry-if-EINTR (lambda () (%tcsetattr input-port TCSAFLUSH initial-input-termios))))) ;; still try resetting output
                             (if (not (and (retry-if-EINTR (lambda () (%tcsetattr output-port TCSAFLUSH initial-output-termios))) input-return))
                                 (errno-error (errno) 'with-rare-mode 'tcsetattr input-port output-port proc))))) ;; might as well exit the procedure
         (the-lflags (bitwise-ior ICANON ECHO))) ;; ~~~~~~~ set for *both* ports???

    (if (or (not initial-input-termios) (not new-input-termios) (not initial-output-termios) (not new-output-termios))
        (sanity-check-error "failure to get or set termios data" 'with-rare-mode input-port output-port proc))

    (term-attrs-lflag-set! new-input-termios
                           (bitwise-and (term-attrs-lflag new-input-termios) (bitwise-not the-lflags)))
    (term-attrs-cc-element-set! new-input-termios 1 VMIN) ;; ~~~~ ought to transpose array index and value to put in it
    (term-attrs-cc-element-set! new-input-termios 0 VTIME) ;; ~~~~ ought to transpose array index and value to put in it
    (term-attrs-lflag-set! new-output-termios
                           (bitwise-and (term-attrs-lflag new-output-termios) (bitwise-not the-lflags)))
    (dynamic-wind
        (lambda ()      ;; set output port first since input port is the same + VMIN and VTIME, we're probably doing duplicate tcsetattrs at the OS level
          (if (not (and (retry-if-EINTR (lambda () (%tcsetattr output-port TCSAFLUSH new-output-termios)))
                        (retry-if-EINTR (lambda () (%tcsetattr input-port TCSAFLUSH new-input-termios)))))
              (errno-error (errno) 'with-rare-mode 'tcsetattr input-port output-port proc)

              ;; For historical reasons, tcsetattr returns 0 if *any*
              ;; of the attribute changes took, so we must check to
              ;; see if all have been set
              (let ((real-new-input-termios (%tcgetattr input-port))
                    (real-new-output-termios (%tcgetattr output-port)))
                (if (not (and real-new-input-termios real-new-output-termios))
                    (begin (reset-terminal)
                           (errno-error (errno) 'with-rare-mode 'tcgetattr input-port output-port proc))
                    (if (not (and (equal? 0 (bitwise-and (term-attrs-lflag real-new-input-termios) the-lflags))
                                  (equal? 1 (term-attrs-cc-element real-new-input-termios VMIN))
                                  (equal? 0 (term-attrs-cc-element real-new-input-termios VTIME))
                                  (equal? 0 (bitwise-and (term-attrs-lflag real-new-output-termios) the-lflags))))
                        (begin (reset-terminal)
                               (sanity-check-error "a termios update failed" 'with-rare-mode input-port output-port proc)))))))
        (lambda () (proc input-port output-port))
        (lambda ()
          (reset-terminal)))))

(define (without-echo input-port output-port proc)
  (if (not (and (port? input-port) (port? output-port)))
      (sanity-check-error "first two arguments must be ports" 'without-echo input-port output-port proc))
  (if (not (and (terminal? input-port) (terminal? output-port)))
      (sanity-check-error "first two arguments must be terminal ports" 'without-echo input-port output-port proc))
  (if (not (and (input-port? input-port) (output-port? output-port)))
      (sanity-check-error "first two arguments must be an input and output ports, respectively" 'without-echo input-port output-port proc))

  (let* ((initial-output-termios (%tcgetattr output-port))
         (new-output-termios (%tcgetattr output-port)) ;; ~~~~ because of tagging, how to copy is not obvious
         (reset-terminal (lambda ()
                           (if (not (retry-if-EINTR (lambda () (%tcsetattr output-port TCSAFLUSH initial-output-termios))))
                               (errno-error (errno) 'without-echo 'tcsetattr output-port proc)))) ;; might as well exit the procedure
         (the-lflags (bitwise-ior ECHO ECHOE ECHOK ECHONL)))

    (if (or (not initial-output-termios) (not new-output-termios))
        (sanity-check-error "failure to get or set termios data" 'without-echo output-port proc))
    (term-attrs-lflag-set! new-output-termios
                           (bitwise-and (term-attrs-lflag new-output-termios) (bitwise-not the-lflags)))
    (dynamic-wind
        (lambda ()
          (if (not (retry-if-EINTR (lambda () (%tcsetattr output-port TCSAFLUSH new-output-termios))))
              (errno-error (errno) 'without-echo 'tcsetattr output-port proc)

              ;; For historical reasons, tcsetattr returns 0 if *any*
              ;; of the attribute changes took, so we must check to
              ;; see if all have been set
              (let ((real-new-output-termios (%tcgetattr output-port)))
                (if (not real-new-output-termios)
                    (begin (reset-terminal)
                           (errno-error (errno) 'without-echo 'tcgetattr output-port proc))
                    (if (not (equal? 0 (bitwise-and (term-attrs-lflag real-new-output-termios) the-lflags)))
                        (begin (reset-terminal)
                               (sanity-check-error "a termios update failed" 'without-echo output-port proc)))))))
        (lambda () (proc input-port output-port))
        (lambda ()
          (reset-terminal)))))
|#
