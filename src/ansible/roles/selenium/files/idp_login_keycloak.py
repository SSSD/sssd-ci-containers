#!/opt/test_venv/bin/python3

import os
import sys
import tempfile

from selenium import webdriver
from datetime import datetime
from packaging.version import parse
from selenium.webdriver.firefox.options import Options
from selenium.webdriver.common.by import By
from selenium.webdriver.support.ui import WebDriverWait
from selenium.webdriver.support import expected_conditions as EC

# Create a isolated runtime directory for the 'nobody' user
runtime_dir = tempfile.mkdtemp(prefix="selenium_runtime_")
os.chmod(runtime_dir, 0o700)

# Update environment variables for the current process
env = os.environ.copy()
env["XDG_RUNTIME_DIR"] = runtime_dir
env["HOME"] = runtime_dir  # Ensures dconf/profile writes to a safe location

if (len(sys.argv) - 1) != 2:
    print("Incorrect number of arguments")
    print(f"Usage: {sys.argv[0]} <verification_uri> <username>")
    print("The password is read from stdin to keep it out of the process "
          "listing and any command logging.")
    sys.exit(2)

verification_uri = sys.argv[1]
username = sys.argv[2]
# Read the password from stdin so it never appears in argv (process listing)
# or in the caller's command log.
password = sys.stdin.readline().rstrip("\n")
password_new = None

if ":::" in password:
    password, password_new = password.split(':::', 1)

options = Options()
options.binary_location = "/opt/test_venv/bin/firefox"
if  parse(webdriver.__version__) < parse('4.10.0'):
    options.headless = True
    driver = webdriver.Firefox(executable_path="/opt/test_venv/bin/geckodriver",
        options=options, env=env)
else:
    options.add_argument('-headless')
    service = webdriver.FirefoxService(
        executable_path="/opt/test_venv/bin/geckodriver",
        # Keep at 'info': 'debug'/'trace' log the WebDriver command payloads,
        # which would capture the send_keys password text in the log file.
        service_args=['--log', 'info'],
        log_output="/tmp/123gecko.log",
        env=env)
    driver = webdriver.Firefox(options=options, service=service)

driver.get(verification_uri)
try:
    element = WebDriverWait(driver, 30).until(
        EC.presence_of_element_located((By.ID, "username")))
    driver.find_element(By.ID, "username").send_keys(username)
    driver.find_element(By.ID, "password").send_keys(password)
    driver.find_element(By.ID, "kc-login").click()

    if password_new is not None:
        element = WebDriverWait(driver, 20).until(
            EC.presence_of_element_located((By.ID, "password-new")))

        driver.find_element(By.ID, "password-new").send_keys(password_new)
        driver.find_element(By.ID, "password-confirm").send_keys(password_new)
        driver.find_element(By.ID, "kc-submit").click()

    element = WebDriverWait(driver, 20).until(
        EC.presence_of_element_located((By.ID, "kc-login")))
    driver.find_element(By.ID, "kc-login").click()

    assert "Device Login Successful" in driver.page_source
finally:
    now = datetime.now().strftime("%M-%S")
    driver.get_screenshot_as_file("/var/log/selenium-screenshot-%s.png" % now)
    driver.quit()

