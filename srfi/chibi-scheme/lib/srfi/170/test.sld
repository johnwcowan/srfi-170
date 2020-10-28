;; please see copyright notice in ./COPYING

;;;;;;;;;; WARNING: ;;;;;;;;;;
;;
;; This SRFI is generally a side effecting one, so tests often depend
;; on the state left by previous ones if they worked.
;;
;; If you're sufficiently daring, this test suite runs fine as root,
;; and some things can only be tested if run as root.  The only caveat
;; is that before you try to run it as a normal user again, you must
;; manually delete the tmp-containing-dir
;;

(define-library (srfi 170 test)
  (export run-tests)

  (import (scheme base)

          (chibi)
          (only (chibi ast) gc)
          (only (chibi filesystem) file-exists? delete-file open)
          (chibi optional) ;; Snow package for optional args
          (only (chibi process) exit) ;; for printf style debugging
          (chibi test)

          (only (srfi 1) alist-cons list-index)
          (only (srfi 19) time-monotonic time-utc make-time time? time-type time-second time-nanosecond)
          (only (srfi 69) make-hash-table hash-table-set! hash-table-ref)
          (only (srfi 98) get-environment-variable)
          (only (srfi 115) regexp-replace-all regexp-split)
          (only (srfi 132) list-sort) ;; note list-sort truncates ending pair cdr not being ()
          (srfi 151) ;; bitwise operators
          ;; (only (srfi 158) generator->list) ;; not in Chibi Scheme, SRFI supplied implemention is very complicated....
          (srfi 170)

          (srfi 170 posix-error)
          )

  (include-shared "170")
  (include-shared "aux")

  (include "common.scm")

  (begin

    ;; Inverse of test-error, mutated from test-not, only errors if an
    ;; exception is raised

    (define-syntax test-not-error
      (syntax-rules ()
        ((_ expr) (test-assert (begin expr #t)))
        ((_ name expr) (test-assert name (begin expr #t)))))

    (define the-error #f)

    (define the-string-port (open-input-string "plover"))

    (define tmp-containing-dir "/tmp/chibi-scheme-srfi-170-test-xyzzy")
    (define tmp-dir-1 "/tmp/chibi-scheme-srfi-170-test-xyzzy/dir-1")
    (define tmp-dir-2 "/tmp/chibi-scheme-srfi-170-test-xyzzy/dir-2")
    (define tmp-fifo "/tmp/chibi-scheme-srfi-170-test-xyzzy/fifo")
    (define tmp-file-1 "/tmp/chibi-scheme-srfi-170-test-xyzzy/file-1")
    (define tmp-file-1-basename "file-1")
    (define tmp-file-2 "/tmp/chibi-scheme-srfi-170-test-xyzzy/file-2")
    (define tmp-dot-file "/tmp/chibi-scheme-srfi-170-test-xyzzy/.dot-file")
    (define tmp-dot-file-basename ".dot-file")
    (define tmp-hard-link "/tmp/chibi-scheme-srfi-170-test-xyzzy/hard-link")
    (define tmp-symlink "/tmp/chibi-scheme-srfi-170-test-xyzzy/symlink")
    (define tmp-symlink-basename "symlink")

    (define tmp-no-filesystem-object "/tmp/chibi-scheme-srfi-170-test-xyzzy/no-filesystem-object")
    (define bogus-path "/foo/bar/baz/quux/xyzzy/plover/plugh")

    (define the-text-string "The quick brown fox jumps over the lazy quux")
    (define the-text-string-length (string-length the-text-string))
    (define the-binary-bytevector (bytevector 0 1 2 3 4 5 6 7 8 9))
    (define the-binary-bytevector-length (bytevector-length the-binary-bytevector))
    (define open-create-truncate (bitwise-ior open/create open/truncate))
    (define open-write-create-truncate (bitwise-ior open/write open/create open/truncate))

    (define starting-dir (current-directory))

    (define no-dot (list-sort string<? '("dir-1" "fifo" "file-1" "hard-link" "symlink")))
    (define with-dot (list-sort string<? '("dir-1" ".dot-file" "fifo" "file-1" "hard-link" "symlink")))

    (define over-max-path "/tmp/aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa")

    (define (delete-tmp-test-files)
      (test-not-error (delete-filesystem-object tmp-dir-1))
      (test-not-error (delete-filesystem-object tmp-dir-2))
      (test-not-error (delete-filesystem-object tmp-fifo))
      (test-not-error (delete-filesystem-object tmp-symlink)) ;; up here to avoid problem with file-exists? check
      (test-not-error (delete-filesystem-object tmp-file-1))
      (test-not-error (delete-filesystem-object tmp-file-2))
      (test-not-error (delete-filesystem-object tmp-dot-file))
      (test-not-error (delete-filesystem-object tmp-hard-link))
      (test-not-error (delete-filesystem-object tmp-containing-dir)))

    (define (create-tmp-test-file fname)
      (call-with-output-file fname
        (lambda (out) (display "plugh" out)))
      (test-assert (file-exists? fname)))

    (define (is-string-in-list? str lst)
      (list-index (lambda (f) (equal? str f)) lst))

    (define (generator->list g)
      (let ((the-item (g)))
        (if (eof-object? the-item)
            '()
            (cons the-item
                  (generator->list g)))))

    (define (maybe-test-socket fname)
      (if (file-exists? fname)
          (file-info-socket? (file-info fname #f))
          #t))

    (define (run-tests)

      (test-group "srfi-170: POSIX API"

        (test-group "Prologue: umask, delete-filesystem-object any old temporary files and directories"

          ;; ~~~~~~~~ need to test that PATH_MAX is no larger than 4096
          ;; ~~~~~~~~ need to test that term/l-ctermid is no larger than 1024

          (delete-tmp-test-files)

          ;; From 3.5 Process state, to set up for following file system changes

          (test-assert (set-umask! #o2))
          (test #o2 (umask))

          ;; Create containing directory so we'll have a place for 3.2  I/O

          (test-not-error (create-directory tmp-containing-dir))
          (test #o775 (bitwise-and (file-info:mode (file-info tmp-containing-dir #t)) #o777)) ; test umask
          (test-assert (file-exists? tmp-containing-dir))
          (test-not-error (delete-directory tmp-containing-dir))
          (test-not-error (create-directory tmp-containing-dir #o755))
          (test-assert (file-exists? tmp-containing-dir))
          (test #o755 (bitwise-and (file-info:mode (file-info tmp-containing-dir #t)) #o777))

          ) ;; end prologue


        (test-group "3.1  Errors"

          ;; tests from old SRFI 198 implementation

          (test #f (posix-error? 1))

          (set! the-error (make-posix-error 1))
          (test 'error (posix-error-error-set the-error))
          (test #f (posix-error-number the-error))
          (test #f (posix-error-name the-error))
          (test 'make-posix-error (posix-error-scheme-procedure the-error))
          (test #f (posix-error-posix-interface the-error))
          (test "Malformed call to make-posix-error, not a list; see data for details" (posix-error-message the-error))
          (test '((arguments . 1)) (posix-error-data the-error))

          (set! the-error (make-posix-error '(1)))
          (test 'error (posix-error-error-set the-error))
          (test #f (posix-error-number the-error))
          (test #f (posix-error-name the-error))
          (test 'make-posix-error (posix-error-scheme-procedure the-error))
          (test #f (posix-error-posix-interface the-error))
          (test "Malformed call to make-posix-error, not an alist; see data for details" (posix-error-message the-error))
          (test '((arguments 1)) (posix-error-data the-error))

          (set! the-error (make-posix-error '((1 . 1))))
          (test 'error (posix-error-error-set the-error))
          (test #f (posix-error-number the-error))
          (test #f (posix-error-name the-error))
          (test 'make-posix-error (posix-error-scheme-procedure the-error))
          (test #f (posix-error-posix-interface the-error))
          (test "Malformed call to make-posix-error, first key must be a symbol; see data for details" (posix-error-message the-error))
          (test '((arguments (1 . 1))) (posix-error-data the-error))

          (set! the-error (make-posix-error '((foo . 1))))
          (test 'error (posix-error-error-set the-error))
          (test #f (posix-error-number the-error))
          (test #f (posix-error-name the-error))
          (test 'make-posix-error (posix-error-scheme-procedure the-error))
          (test #f (posix-error-posix-interface the-error))
          (test "Malformed call to make-posix-error, missing error-set; see data for details" (posix-error-message the-error))
          (test '((arguments (foo . 1))) (posix-error-data the-error))

          (set! the-error (make-posix-error '((error-set . error))))
          (test 'error (posix-error-error-set the-error))
          (test #f (posix-error-number the-error))
          (test #f (posix-error-name the-error))
          (test #f (posix-error-scheme-procedure the-error))
          (test #f (posix-error-posix-interface the-error))
          (test #f (posix-error-message the-error))
          (test #f (posix-error-data the-error))

          ;; Make sure the error raising code isn't malfunctioning and raising a different error
          (test-error ((with-exception-handler
                        (lambda (exception) (set! the-error exception))
                        (lambda () (raise-posix-error '((error-set . error)))))))
          (test-assert (posix-error? the-error))

          ;; Make a "real" error
          (set! the-error (make-posix-error '((error-set . errno)
                                              (errno-number . 2)
                                              (errno-name . ENOENT)
                                              (scheme-procedure . open-file)
                                              (posix-interface . open)
                                              (message . "open-file called open: ENOENT: No such file or directory")
                                              (data . ((arguments . ("not-a-valid-filename" 0 428))
                                                       (heritage . "SRFI 170"))))))

          (test 'errno (posix-error-error-set the-error))
          (test 2 (posix-error-number the-error))
          (test 'ENOENT (posix-error-name the-error))
          (test 'open-file (posix-error-scheme-procedure the-error))
          (test 'open (posix-error-posix-interface the-error))
          (test "open-file called open: ENOENT: No such file or directory" (posix-error-message the-error))
          (test '("not-a-valid-filename" 0 428) (cdr (assq 'arguments (posix-error-data the-error))))
          (test "SRFI 170" (cdr (assq 'heritage (posix-error-data the-error))))


          ;; tests using the above
          (test 0 (errno))
          (test-not-error (set-errno E2BIG))
          (set-errno E2BIG)
          (test E2BIG (errno))
          (test-assert (string? (errno-string (errno))))
          (test-assert (string? (errno-string E2BIG)))
          (set-errno E2BIG)
          (test-assert (equal? (errno-string (errno)) (errno-string E2BIG)))

          ;; Make sure the error raising code isn't malfunctioning and raising a different error
          (test-error ((with-exception-handler
                        (lambda (exception) (set! the-error exception))
                        (lambda () (errno-error 2 'test-of-errno-error-procedure-symbol 'test-of-errno-error-syscall-symbol 1 2 3 4)))))
          (test-assert (posix-error? the-error))
          (test 'errno (posix-error-error-set the-error))
          (test 2 (posix-error-number the-error))
          (test 'ENOENT (posix-error-name the-error))
          (test 'test-of-errno-error-procedure-symbol (posix-error-scheme-procedure the-error))
          (test 'test-of-errno-error-syscall-symbol (posix-error-posix-interface the-error))
          (test "test-of-errno-error-procedure-symbol called test-of-errno-error-syscall-symbol: ENOENT: No such file or directory"
                (posix-error-message the-error))
          (test '(1 2 3 4) (cdr (assq 'arguments (posix-error-data the-error))))

          ;; Make sure the error raising code works for a real error
          (test-error ((with-exception-handler
                        (lambda (exception) (set! the-error exception))
                        (lambda () (open-file bogus-path textual-input 0)))))
          (test-assert (posix-error? the-error))
          (test 'errno (posix-error-error-set the-error))
          (test 2 (posix-error-number the-error))
          (test 'ENOENT (posix-error-name the-error))
          (test 'open-file (posix-error-scheme-procedure the-error))
          (test 'open (posix-error-posix-interface the-error))
          (test "open-file called open: ENOENT: No such file or directory"
                (posix-error-message the-error))
          (test (list bogus-path open/read #o666) (cdr (assq 'arguments (posix-error-data the-error))))

          (test-error ((with-exception-handler
                        (lambda (exception) (set! the-error exception))
                        (lambda () (sanity-check-error "Sanity check error test message" 'test-of-errno-error-procedure-symbol 1 2 3 4)))))
          (test-assert (posix-error? the-error))
          (test 'sanity-check (posix-error-error-set the-error))
          (test #f (posix-error-number the-error))
          (test #f (posix-error-name the-error))
          (test 'test-of-errno-error-procedure-symbol (posix-error-scheme-procedure the-error))
          (test #f (posix-error-posix-interface the-error))
          (test "test-of-errno-error-procedure-symbol: Sanity check error test message"
                (posix-error-message the-error))
          (test '(1 2 3 4) (cdr (assq 'arguments (posix-error-data the-error))))


          ) ;; end errors


        (test-group "3.2  I/O"

          (test-error (open-file 1 1 1))
          (test-error (open-file 1 1 1 1))
          (test-error (open-file 1 1 1 1 1))
          (test-error (open-file bogus-path binary-input 0))

          ;; None of are buffer-none, buffer-block, or buffer-line are implemented or even checked for as of yet:

          (let* ((dev-zero-port (open-file "/dev/zero" binary-input 0)))
            (test-assert 0 (read-char dev-zero-port))
            (test-not-error (close-port dev-zero-port)))

          (let ((the-port (open-file tmp-file-1 textual-output open-create-truncate)))
            (test-not-error (write-string the-text-string the-port))
            (test-not-error (close-port the-port)))
          (let ((the-port (open-file tmp-file-1 textual-input 0)))
            (test-assert (equal? the-text-string (read-string the-text-string-length the-port)))
            (test-assert (eof-object? (read-char the-port)))
            (test-not-error (close-port the-port)))
          (let ((the-port (open-file tmp-file-1 binary-output open-create-truncate)))
            (test-not-error (write-bytevector the-binary-bytevector the-port))
            (test-not-error (close-port the-port)))
          (let ((the-port (open-file tmp-file-1 binary-input 0)))
            (test-assert (equal? the-binary-bytevector (read-bytevector the-binary-bytevector-length the-port)))
            (test-assert (eof-object? (read-char the-port)))
            (test-not-error (close-port the-port)))

          (test-error (open-file tmp-file-1 binary-input/output 0))

          (let* ((the-fileno (open tmp-file-1 open-write-create-truncate))
                 (the-fd (%fileno-to-fd the-fileno))
                 (the-port (fd->port the-fd textual-output)))
            (test-not-error (write-string the-text-string the-port))
            (test-not-error (close-port the-port)))
          (let* ((the-fileno (open tmp-file-1 open/read 0))
                 (the-fd (%fileno-to-fd the-fileno))
                 (the-port (fd->port the-fd textual-input)))
            (test-assert (equal? the-text-string (read-string the-text-string-length the-port)))
            (test-assert (eof-object? (read-char the-port)))
            (test-not-error (close-port the-port)))
          (let* ((the-fileno (open tmp-file-1 open-write-create-truncate))
                 (the-fd (%fileno-to-fd the-fileno))
                 (the-port (fd->port the-fd binary-output)))
            (test-not-error (write-bytevector the-binary-bytevector the-port))
            (test-not-error (close-port the-port)))
          (let* ((the-fileno (open tmp-file-1 open/read 0))
                 (the-fd (%fileno-to-fd the-fileno))
                 (the-port (fd->port the-fd binary-input)))
            (test-assert (equal? the-binary-bytevector (read-bytevector the-binary-bytevector-length the-port)))
            (test-assert (eof-object? (read-char the-port)))
            (test-not-error (close-port the-port)))

          (test-error (fd->port 4 binary-input/output))

          ) ;; end I/O


        ;; Here because needed for temp-file-prefix
        (test-group "3.11  Environment variables"

          (test #f (get-environment-variable "xyzzy"))
          (test-not-error (set-environment-variable! "xyzzy" "one"))
          (test "one" (get-environment-variable "xyzzy"))
          (test-not-error (set-environment-variable! "xyzzy" "two"))
          (test "two" (get-environment-variable "xyzzy"))
          (test-error (set-environment-variable! "xyzzy=plover" "three"))
          (test-not-error (delete-environment-variable! "xyzzy"))
          (test #f (get-environment-variable "xyzzy"))
          (test-error (delete-environment-variable! "xyzzy=plover"))
          (test-not-error (set-environment-variable! "xyzzy" ""))
          (test "" (get-environment-variable "xyzzy"))
          (test-not-error (delete-environment-variable! "xyzzy"))


          ) ;; end environment variables


        (test-group "3.3  File system"

          ;; ~~~~ test across filesystems, assuming /var is not in same as /tmp
          ;; ~~~~ do some time sanity checking, e.g. get time, subtract a few seconds, test....

          (test-error (create-directory))
          (test-error (create-directory tmp-dir-1 #t))
          (test-not-error (create-directory tmp-dir-1))
          (test-assert (file-exists? tmp-dir-1))
          (test-error (create-directory tmp-dir-1))
          (test-not-error (delete-directory tmp-dir-1))
          (test-not-error (create-directory tmp-dir-1 #o775))

          (test-error (create-fifo))
          (test-error (create-fifo tmp-fifo #t))
          (test-not-error (create-fifo tmp-fifo))
          (test-assert (file-exists? tmp-fifo))
          (test-error (create-fifo tmp-fifo))
          (test-not-error (delete-file tmp-fifo))
          (test-not-error (create-fifo tmp-fifo #o644))
          (test-assert (file-exists? tmp-fifo))
          (test #o644 (bitwise-and (file-info:mode (file-info tmp-fifo #t)) #o777))

          ;; (test-not-error (create-tmp-test-file tmp-file-1)) ;; created above in I/O

          (test-error (create-hard-link tmp-file-1))
          (test-not-error (create-hard-link tmp-file-1 tmp-hard-link))
          (test-assert (file-exists? tmp-hard-link))
          (test-error (create-hard-link tmp-file-1 tmp-hard-link))
          (test-assert (file-exists? tmp-hard-link))

          (test-error (create-symlink tmp-file-1))
          (test-not-error (create-symlink tmp-file-1 tmp-symlink))
          (test-assert (file-exists? tmp-symlink))
          (test-error (create-symlink tmp-file-1 tmp-symlink))
          (test-assert (file-exists? tmp-symlink))

          (test-assert (equal? (file-info:inode (file-info tmp-file-1 #t))
                               (file-info:inode (file-info tmp-symlink #t))))
          (test #f (equal? (file-info:inode (file-info tmp-file-1 #t))
                           (file-info:inode (file-info tmp-symlink #f))))

          (test-error (read-symlink))
          (test-error (read-symlink tmp-file-1))
          (test tmp-file-1 (read-symlink tmp-symlink))

          (test-error (rename-file tmp-file-1))
          (test-not-error (rename-file tmp-file-1 tmp-file-2))
          (test-assert (file-exists? tmp-file-2))
          (test-not (file-exists? tmp-file-1))
          (test-not-error (create-tmp-test-file tmp-file-1))
          (test-not-error (rename-file tmp-file-2 tmp-file-1))
          (test-assert (file-exists? tmp-file-1))
          (test-not (file-exists? tmp-file-2))

          (test-error (rename-file tmp-dir-1))
          (test-not-error (rename-file tmp-dir-1 tmp-dir-2))
          (test-not (file-exists? tmp-dir-1))
          (test-assert (file-exists? tmp-dir-2))
          (test-error (rename-file tmp-dir-1 tmp-dir-2))
          (test-assert (file-exists? tmp-dir-2))
          (test-not (file-exists? tmp-dir-1))
          (test-not-error (create-directory tmp-dir-1))
          (test-error (rename-file tmp-dir-2 tmp-file-1))
          (test-not-error (rename-file tmp-dir-2 tmp-dir-1))
          (test-assert (file-exists? tmp-dir-1))
          (test-not (file-exists? tmp-dir-2))

          (test-error (delete-directory))
          (test-not-error (delete-directory tmp-dir-1))

          (test-not-error (set-file-mode tmp-file-1 #o744))
          (test #o744 (bitwise-and (file-info:mode (file-info tmp-file-1 #t)) #o777))

          (let* ((fi-starting (file-info tmp-file-1 #t))
                 (my-starting-uid (file-info:uid fi-starting))
                 (my-starting-gid (file-info:gid fi-starting)))

            (test-not-error (set-file-owner tmp-file-1 my-starting-uid my-starting-gid))
            (test-not-error (set-file-owner tmp-file-1 owner/unchanged group/unchanged))
            (if (equal? 0 (user-effective-uid))
                (begin (test-not-error (set-file-owner tmp-file-1 1 1))
                       (let ((fi-middle (file-info tmp-file-1 #t)))
                         (test 1 (file-info:uid fi-middle))
                         (test 1 (file-info:gid fi-middle)))
                       (test-not-error (set-file-owner tmp-file-1 0 group/unchanged))
                       (let ((fi-middle (file-info tmp-file-1 #t)))
                         (test 0 (file-info:uid fi-middle))
                         (test 1 (file-info:gid fi-middle)))
                       (test-not-error (set-file-owner tmp-file-1 1 1))
                       (test-not-error (set-file-owner tmp-file-1 owner/unchanged 0))
                       (let ((fi-middle (file-info tmp-file-1 #t)))
                         (test 1 (file-info:uid fi-middle))
                         (test 0 (file-info:gid fi-middle)))
                       (test-not-error (set-file-owner tmp-file-1 my-starting-uid my-starting-gid))))

                       (let ((fi-ending (file-info tmp-file-1 #t)))
                         (test my-starting-uid (file-info:uid fi-ending))
                         (test my-starting-gid (file-info:gid fi-ending))))

          (test-error (set-file-times tmp-file-1 1 2))
          (test-error (set-file-times tmp-file-1 (make-time time-monotonic 0 0) (make-time time-utc 0 0))) ;; the epoch
          (test-error (set-file-times tmp-file-1 (make-time time-monotonic 0 0) (make-time time-monotonic 0 0))) ;; the epoch
          (test-not-error (set-file-times tmp-file-1 (make-time time-utc 0 0) (make-time time-utc 0 0))) ;; the epoch
          (let ((fi (file-info tmp-file-1 #t)))
            (let ((atime (file-info:atime fi))
                  (mtime (file-info:mtime fi))
                  (ctime (file-info:ctime fi)))
              (test-assert (and (time? atime)
                                (eq? time-utc (time-type atime))
                                (equal? (time-second atime) 0)
                                (equal? (time-nanosecond atime) 0)
                                (time? mtime)
                                (eq? time-utc (time-type mtime))
                                (equal? (time-second mtime) 0)
                                (equal? (time-nanosecond mtime) 0)
                                (time? ctime)
                                (eq? time-utc (time-type ctime))
                                (> (time-second ctime) 0)
                                (> (time-nanosecond ctime) 0)))))
          (test-not-error (set-file-times tmp-file-1 time/unchanged time/now))
          (let ((fi (file-info tmp-file-1 #t)))
            (let ((atime (file-info:atime fi))
                  (mtime (file-info:mtime fi))
                  (ctime (file-info:ctime fi)))
              (test-assert (and (time? atime)
                                (equal? (time-second atime) 0)
                                (equal? (time-nanosecond atime) 0)
                                (time? mtime)
                                (> (time-second mtime) 0)
                                (> (time-nanosecond mtime) 0)
                                (time? ctime)
                                (> (time-second ctime) 0)
                                (> (time-nanosecond ctime) 0)))))
          (test-not-error (set-file-times tmp-file-1)) ;; "now" for both
          (let ((fi (file-info tmp-file-1 #t)))
            (let ((atime (file-info:atime fi))
                  (mtime (file-info:mtime fi))
                  (ctime (file-info:ctime fi)))
              (test-assert (and (time? atime)
                                (> (time-second atime) 0)
                                (> (time-nanosecond atime) 0)
                                (time? mtime)
                                (> (time-second mtime) 0)
                                (> (time-nanosecond mtime) 0)
                                (time? ctime)
                                (> (time-second ctime) 0)
                                (> (time-nanosecond ctime) 0)))))
          (test-not-error (create-directory tmp-dir-1))
          (test-not-error (set-file-times tmp-dir-1)) ;; "now" for both
          (let ((fi (file-info tmp-dir-1 #t)))
            (let ((atime (file-info:atime fi))
                  (mtime (file-info:mtime fi))
                  (ctime (file-info:ctime fi)))
              (test-assert (and (time? atime)
                                (> (time-second atime) 0)
                                (> (time-nanosecond atime) 0)
                                (time? mtime)
                                (> (time-second mtime) 0)
                                (> (time-nanosecond mtime) 0)
                                (time? ctime)
                                (> (time-second ctime) 0)
                                (> (time-nanosecond ctime) 0)))))

          (test the-binary-bytevector-length (file-info:size (file-info tmp-file-1  #t)))
          (test-not-error (truncate-file tmp-file-1 30))
          (test 30 (file-info:size (file-info tmp-file-1 #t)))
          (let ((the-port (open-output-file tmp-file-1))) ;; note this truncates the file to 0 length
            (test-not-error (truncate-file the-port 10)) ;; this should make the file 10 bytes of 0s
            (test 10 (file-info:size (file-info tmp-file-1 #t)))
            (test-not-error (close-output-port the-port)))

          ;; test remaining file-info features

          (let ((fi (file-info tmp-file-1 #t)))
            (test-assert (file-info? fi))
            (test-assert (file-info:device fi))
            (test 2 (file-info:nlinks fi))
            (test (user-uid) (file-info:uid fi))
            (cond-expand
             (linux (test (user-gid) (file-info:gid fi)))) ;; OpenBSD's default group for main user is wheel
            (test-assert (file-info:rdev fi))
            (cond-expand
             ((not windows)
              (test-assert (> (file-info:blksize fi) 0))
              (test-assert (file-info:blocks fi)))) ;; can be 0, inside the inode, for a file this small
            (let ((atime (file-info:atime fi))
                  (mtime (file-info:mtime fi))
                  (ctime (file-info:ctime fi)))
              (test-assert (and (time? atime)
                                (> (time-second atime) 0)
                                (> (time-nanosecond atime) 0)
                                (time? mtime)
                                (> (time-second mtime) 0)
                                (> (time-nanosecond mtime) 0)
                                (time? ctime)
                                (> (time-second ctime) 0)
                                (> (time-nanosecond ctime) 0))))
            (test-not (file-info-directory? fi))
            (test-not (file-info-fifo? fi))
            (test-assert (file-info-regular? fi))
            (test-not (file-info-socket? fi))
            (test-not (file-info-device? fi))
            )

          (let* ((the-port (open-input-file tmp-file-1))
                 (fi (file-info the-port 'follow-is-ignored)))
            (test-assert (file-info? fi))
            (test 2 (file-info:nlinks fi))
            (test (user-uid) (file-info:uid fi))
            (cond-expand
             (linux (test (user-gid) (file-info:gid fi)))) ;; OpenBSD's default group for main user is wheel
            (let ((atime (file-info:atime fi))
                  (mtime (file-info:mtime fi))
                  (ctime (file-info:ctime fi)))
              (test-assert (and (time? atime)
                                (> (time-second atime) 0)
                                (> (time-nanosecond atime) 0)
                                (time? mtime)
                                (> (time-second mtime) 0)
                                (> (time-nanosecond mtime) 0)
                                (time? ctime)
                                (> (time-second ctime) 0)
                                (> (time-nanosecond ctime) 0))))
            (test-not (file-info-directory? fi))
            (test-not (file-info-fifo? fi))
            (test-not (file-info-symlink? fi))
            (test-assert (file-info-regular? fi))
            (test-not (file-info-socket? fi))
            (test-not (file-info-device? fi))
            (test-not-error (close-input-port the-port))
            )

          (test-assert (file-info-directory? (file-info tmp-containing-dir #t)))
          (test-assert (file-info-fifo? (file-info tmp-fifo #t)))
          (test-assert (file-info-symlink? (file-info tmp-symlink #f)))

          ;; hopefully find a standard socket file and test the predicate
          ;; test harmlessness of maybe-test-socket with non-existant file
          (test-assert (maybe-test-socket bogus-path))

          ;; From hga's Ubuntu Bionic Beaver desktop system:
          (cond-expand (linux
            (test-assert (maybe-test-socket "/var/lib/lxd/unix.socket"))
            (test-assert (maybe-test-socket "/var/spool/postfix/dev/log"))
            (test-assert (maybe-test-socket "/run/cups/cups.sock"))
            (test-assert (maybe-test-socket "/run/acpid.socket"))
            (test-assert (maybe-test-socket "/run/dbus/system_bus_socket"))
            (test-assert (maybe-test-socket "/run/uuidd/request"))
            (test-assert (maybe-test-socket "/run/systemd/private"))
            (test-assert (maybe-test-socket "/run/systemd/notify"))
            (test-assert (maybe-test-socket "/run/udev/control"))))

          ;; OpenBSD 6.7
          (cond-expand (openbsd
             (test-assert (maybe-test-socket "/var/run/ntpd.sock"))
             (test-assert (maybe-test-socket "/var/run/smtpd.sock"))
             (test-assert (maybe-test-socket "/var/run/cron.sock"))
             (test-assert (maybe-test-socket "/dev/log"))))

          (test-assert (file-info-device? (file-info "/dev/tty" #f))) ;; pretty sure this is safe

          (test-not-error (create-tmp-test-file tmp-dot-file))

          (test-assert (equal? no-dot (list-sort string<? (directory-files tmp-containing-dir))))
          (test-assert (equal? with-dot (list-sort string<? (directory-files tmp-containing-dir #t))))

          (test-error (make-directory-files-generator tmp-no-filesystem-object))
          (let ((g (make-directory-files-generator tmp-containing-dir)))
            (test-assert (equal? no-dot (list-sort string<? (generator->list g)))))
          (let ((g (make-directory-files-generator tmp-containing-dir #t)))
            (test-assert (equal? with-dot (list-sort string<? (generator->list g)))))

          ;; the higher level directory-files and make-directory-files-generator
          ;; tests above test the normal function of open-/read-/close-directory

          (test-error (open-directory tmp-no-filesystem-object))
          (let ((dirobj (open-directory tmp-containing-dir)))
            (test-not-error (close-directory dirobj))
            (test-error (close-directory dirobj))
            (test-error (read-directory dirobj)))

          (test-not-error (set-current-directory! tmp-containing-dir))
          (test tmp-containing-dir (real-path "."))
          (test tmp-file-1 (real-path tmp-file-1-basename))
          (test tmp-file-1 (real-path (string-append "./" tmp-file-1-basename)))
          (test tmp-file-1 (real-path tmp-symlink-basename))
          (test-error (real-path bogus-path))
          (test-not-error (set-current-directory! starting-dir))

          (test-error (free-space #\a))
          (test-error (free-space bogus-path))
          (test-error (free-space the-string-port))
          (test-not-error (free-space "/tmp"))

          ;; the following free-space tests are inherantly fragile, between the two invocations of free-space something else may change free space on /tmp
;;          (test (free-space "/tmp") (free-space tmp-containing-dir))
;;          (test (free-space "/tmp") (free-space tmp-file-1))

          ;; ~~~ test for an decrease in free space, large so less likely to be a false positive
          (truncate-file tmp-file-1 0)
          (let* ((the-port (open-output-file tmp-file-1))
                 (the-big-string (make-string (* 1024 1024) 0))
                 (the-original-free-space (free-space tmp-file-1)))
            (do ((i 32 (- i 1)))
                ((< i 1))
              (write-string the-big-string the-port))
            (flush-output-port the-port)
            (test-assert (< (free-space tmp-file-1) the-original-free-space)))
          ;; truncate-file must be called outside of test group (see below) because of how (chibi test) catches raises

          (test-assert (string? (temp-file-prefix)))
          (set-environment-variable! "TMPDIR" "foo")
          (parameterize ((temp-file-prefix "foo/"))
            (test "foo/" (temp-file-prefix)))
          (delete-environment-variable! "TMPDIR")
          (test (string-append "/tmp/" (number->string (pid))) (temp-file-prefix))

          ;; can't test skipping past an existing temp file due to the
          ;; suffix being completely random....:

          (let ((the-filename (create-temp-file)))
            (test-assert (file-exists? the-filename))
            (test "/tmp/" (string-copy the-filename 0 5))
            (test-not-error (delete-file the-filename))) ;; cleaning up after self, but bad for debugging

          (let ((the-filename (create-temp-file tmp-containing-dir))
                (the-prefix (string-append tmp-containing-dir ".")))
            (test-assert (file-exists? the-filename))
            (test the-prefix (string-copy the-filename 0 (string-length the-prefix)))
            (test-not-error (delete-file the-filename))) ;; cleaning up after self, but bad for debugging

          (parameterize ((temp-file-prefix tmp-file-1))
            (let ((the-filename (create-temp-file))
                  (the-prefix (string-append tmp-file-1 ".")))
              (test-assert (file-exists? the-filename))
              (test the-prefix (string-copy the-filename 0 (string-length the-prefix)))
              (test-not-error (delete-file the-filename)))) ;; cleaning up after self, but bad for debugging

          (if (not (equal? 0 (user-effective-uid)))
              (test-error (create-temp-file bogus-path)))

          ;; ~~~ call-with-temporary-filename

          ) ;; end file system

        (truncate-file tmp-file-1 30)

        (test-group "3.5  Process state"

          ;; umask and set-umask exercised in the prologue to set up
          ;; for following file system tests

          (test-assert (string? (current-directory)))
          (test-error (set-current-directory! over-max-path))
          (test-not-error (set-current-directory! tmp-containing-dir))
          (test tmp-containing-dir (current-directory))
          (test-not-error (file-info tmp-file-1-basename #t)) ; are we there?

          (cond-expand (openbsd
            (test-not-error (set-file-mode tmp-containing-dir #o000))
            (if (equal? 0 (user-effective-uid))
                (test-not-error (current-directory))
                (test-error (current-directory)))
            (test-not-error (set-file-mode tmp-containing-dir #o755))))

          (test-assert (pid))

          (test 0 (nice 0))

          ;; setting niceness positive in epilogue to not slow down rest of tests

          (test-assert (> (user-uid) -1))
          (test-assert (> (user-gid) -1))
          (test-assert (> (user-effective-uid) -1))
          (test-assert (> (user-effective-gid) -1))
          (let ((the-user-gid-list (user-supplementary-gids)))
            (test-assert (list? (user-supplementary-gids)))
            ;; while POSIX optional, in practice Linux and OpenBSD
            ;; include the user-effective-gid
            (test-assert (any (lambda (g)
                                (equal? g (user-effective-gid)))
                              the-user-gid-list)))

          ) ;; end process state


        (test-group "3.6  User and group database access"

          (test-assert (user-info? (user-info 0)))
          (test 0 (user-info:uid (user-info 0)))
          (test-assert (user-info? (user-info "root")))
          (test 0 (user-info:uid (user-info "root")))

          (test-not (user-info? (user-info (- 60000 39)))) ;; Normal OpenBSD max - random number
          (test-not (user-info? (user-info bogus-path)))

          (let ((the-parsed-user-name (user-info:parsed-full-name (user-info 0))))
            (test-assert (list? the-parsed-user-name))
            (test-assert (string? (car the-parsed-user-name))))

          (test '("") (parse-gecos "" ""))
          (test '("Test User") (parse-gecos "Test User" ""))
          (test '("") (parse-gecos "" "test"))
          (test '("Test User" "" "" "") (parse-gecos "Test User,,," "test"))
          (test '("Test UserTest" "" "" "") (parse-gecos "Test User&,,," "test"))
          (test '("Test User" "@" "" "") (parse-gecos "Test User,@,," "test"))

          (test-assert (group-info? (group-info 0)))
          (test 0 (group-info:gid (group-info 0)))
          ;; group 0 is wheel on OpenBSD, daemon works for it and Bionic Beaver
          (test-assert (group-info? (group-info "daemon")))
          (test 1 (group-info:gid (group-info "daemon")))

          (test-not (group-info? (group-info (- 60000 39))))
          (test-not (group-info? (group-info bogus-path)))

          ) ;; end user and group database access


        (test-group "3.10  Time"

          (test-not-error (posix-time))
          (test-not-error (monotonic-time))
          (let ((t1 (posix-time))
                (t2 (monotonic-time)))
            (test-assert (and (time? t1)
                              (> (time-second t1) 0)
                              (> (time-nanosecond t1) 0)
                              (time? t2)
                              (> (time-second t2) 0)
                              (> (time-nanosecond t2) 0))))
          ) ;; end time


        (test-group "3.12  Terminal device control"

          (test-error (terminal? -1))
          (test-error (terminal? 0))
          (test-error (terminal? "a"))
          (test-error (terminal? #f))
          (test-assert (terminal? (current-input-port)))
          (test-not (terminal? the-string-port))
          (let ((port-not-terminal (open-input-file tmp-file-1)))
            (test-not (terminal? port-not-terminal))
            (close-port port-not-terminal))

#|
;; All terminal procedures except for terminal? will be moved to a new
;; SRFI; this working code is left here for it.

          (test-error (terminal-file-name 1))
          (test-error (terminal-file-name the-string-port))
          (let ((port-not-terminal (open-input-file tmp-file-1)))
            (test-error (terminal-file-name port-not-terminal))
            (close-port port-not-terminal))
          (test-assert (string? (terminal-file-name (current-input-port))))
          (test-assert (string? (terminal-file-name (current-output-port))))
          (test-assert (string? (terminal-file-name (current-error-port))))

          ;; These with- and without- tests only test for errors, and
          ;; getting to and out of the supplied proc, not the actual
          ;; detailed terminal mode which has to be done by hand

          (test-error (with-raw-mode 1 (current-output-port) 2 4 (lambda (x y) 'something-for-body)))
          (test-error (with-raw-mode (current-input-port) 1 2 4 (lambda (x y) 'something-for-body)))
          (test-error (with-raw-mode the-string-port (current-output-port) 2 4 (lambda (x y) 'something-for-body)))
          (test-error (with-raw-mode (current-input-port) the-string-port 2 4 (lambda (x y) 'something-for-body)))
          (test-error (with-raw-mode (current-output-port) (current-input-port) 2 4 (lambda (x y) 'something-for-body)))
          ;; ~~~~ test for a file descriptor in port???
          (test 'something-for-body (with-raw-mode (current-input-port) (current-output-port) 2 4 (lambda (x y) 'something-for-body)))

          (test-error (with-rare-mode 1 (current-output-port) (lambda (x y) 'something-for-body)))
          (test-error (with-rare-mode (current-input-port) 1 (lambda (x y) 'something-for-body)))
          (test-error (with-rare-mode the-string-port (current-output-port) (lambda (x y) 'something-for-body)))
          (test-error (with-rare-mode (current-input-port) the-string-port (lambda (x y) 'something-for-body)))
          (test-error (with-rare-mode (current-output-port) (current-input-port) (lambda (x y) 'something-for-body)))
          ;; ~~~~ test for a file descriptor in port???
          (test 'something-for-body (with-rare-mode (current-input-port) (current-output-port) (lambda (x y) 'something-for-body)))

          (test-error (without-echo 1 (current-output-port) (lambda (x y) 'something-for-body)))
          (test-error (without-echo (current-input-port) 1 (lambda (x y) 'something-for-body)))
          (test-error (without-echo the-string-port (current-output-port) (lambda (x y) 'something-for-body)))
          (test-error (without-echo (current-input-port) the-string-port (lambda (x y) 'something-for-body)))
          (test-error (without-echo (current-output-port) (current-input-port) (lambda (x y) 'something-for-body)))
          ;; ~~~~ test for a file descriptor in port???
          (test 'something-for-body (without-echo (current-input-port) (current-output-port) (lambda (x y) 'something-for-body)))
          |#

          ) ;; end terminal device control


        (test-group "Epilogue: cleanup, force a gc, set-priority to 1, 2, 4"

          (close-port the-string-port)

          (test-not-error (gc)) ;; see if we blow up

          ;; in epilogue so most testing is not slowed down

          (test 1 (nice))
          (test 2 (nice 1))
          (test 4 (nice 2))

          ) ;; end epilogue

        ))))
