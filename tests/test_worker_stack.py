"""Run the real core suites on an iOS-sized worker stack in a crash-isolated process."""
from pathlib import Path
import subprocess
import sys
import threading
import unittest

ROOT=Path(__file__).resolve().parents[1]

class WorkerStackRegression(unittest.TestCase):
    def test_load_reset_restore_and_profiles_on_512_kib_worker(self):
        run=subprocess.run([sys.executable,str(Path(__file__).resolve()),'--worker'],cwd=ROOT,
                           capture_output=True,text=True,timeout=90)
        self.assertEqual(run.returncode,0,'512 KiB worker failed (a native stack overflow can terminate the child):\n'+run.stdout+run.stderr)
        self.assertIn('PASS: native suites on 512 KiB worker',run.stdout)

def worker_main():
    # The host main thread is much larger than an iOS dispatch worker. Running
    # these existing fixtures only on the main thread missed the ARM64 reset bug.
    threading.stack_size(512*1024)
    outcomes=[]
    def execute():
        try:
            suite=unittest.defaultTestLoader.loadTestsFromNames(['test_native','test_adventure','test_ice_hockey'])
            result=unittest.TextTestRunner(stream=sys.stdout,verbosity=2).run(suite)
            outcomes.append(result.wasSuccessful())
            if outcomes[-1]:print('PASS: native suites on 512 KiB worker',flush=True)
        except BaseException as error:
            print('FAIL:',repr(error),flush=True);outcomes.append(False)
    thread=threading.Thread(target=execute,name='ios-sized-emulator-worker')
    thread.start();thread.join()
    return 0 if outcomes==[True] else 1

if __name__=='__main__':
    if '--worker' in sys.argv:sys.exit(worker_main())
    unittest.main()
