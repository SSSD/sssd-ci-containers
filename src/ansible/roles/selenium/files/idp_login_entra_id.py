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

if (len(sys.argv) - 1) != 3:
    print("Incorrect number of arguments")
    print(f"Usage: {sys.argv[0]} <verification_uri> <user_code> <username>")
    print("The password is read from stdin to keep it out of the process "
          "listing and any command logging.")
    sys.exit(2)

verification_uri = sys.argv[1]
user_code = sys.argv[2]
username = sys.argv[3]
# Read the password from stdin so it never appears in argv (process listing)
# or in the caller's command log.
password = sys.stdin.readline().rstrip("\n")
password_new = None

if ":::" in password:
    password, password_new = password.split(':::', 1)

options = Options()
options.binary_location = "/opt/test_venv/bin/firefox"

if parse(webdriver.__version__) < parse('4.10.0'):
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
        log_output="/tmp/entraid-gecko.log",
        env=env)
    driver = webdriver.Firefox(options=options, service=service)

driver.get(verification_uri)
try:
    # Wait for and enter the device code
    element = WebDriverWait(driver, 30).until(
        EC.presence_of_element_located((By.NAME, "otc")))
    driver.find_element(By.NAME, "otc").send_keys(user_code)
    element = WebDriverWait(driver, 10).until(
        EC.element_to_be_clickable((By.ID, "idSIButton9")))
    element.click()

    # Wait for and enter username/email
    element = WebDriverWait(driver, 20).until(
        EC.presence_of_element_located((By.NAME, "loginfmt")))
    driver.find_element(By.NAME, "loginfmt").send_keys(username)
    driver.find_element(By.ID, "idSIButton9").click()

    # Wait for and enter password
    element = WebDriverWait(driver, 20).until(
        EC.element_to_be_clickable((By.NAME, "passwd")))
    driver.find_element(By.NAME, "passwd").send_keys(password)
    driver.find_element(By.ID, "idSIButton9").click()

    # Handle password change if required
    if password_new is not None:
        try:
            element = WebDriverWait(driver, 10).until(
                EC.element_to_be_clickable((By.NAME, "NewPassword")))

            driver.find_element(By.NAME, "OldPassword").send_keys(password)
            driver.find_element(By.NAME, "NewPassword").send_keys(password_new)
            driver.find_element(By.NAME, "ConfirmNewPassword").send_keys(password_new)
            element = WebDriverWait(driver, 10).until(
                EC.element_to_be_clickable((By.ID, "idSIButton9")))
            element.click()
        except:
            pass  # Password change not required

    # Optional "Stay signed in?" (KMSI) prompt - button is idSIButton9
    try:
        element = WebDriverWait(driver, 5).until(
            EC.element_to_be_clickable((By.ID, "idSIButton9")))
        element.click()
    except:
        pass  # KMSI prompt not shown

    # Confirm device authorization. The current Entra ID device-code flow
    # presents an "Are you trying to sign in to ...?" page whose confirm
    # button is "Approve" (id=idBtn_Approve), not the old idSIButton9.
    try:
        element = WebDriverWait(driver, 15).until(
            EC.element_to_be_clickable((By.ID, "idBtn_Approve")))
        element.click()
    except:
        # Fall back to the legacy "Continue"/"Yes" button if present
        try:
            element = WebDriverWait(driver, 5).until(
                EC.element_to_be_clickable((By.ID, "idSIButton9")))
            element.click()
        except:
            pass  # May have already auto-confirmed

    # Check for success indicators
    page_lower = driver.page_source.lower()
    assert "signed in" in page_lower, "'signed in' not found on final page"
    assert "close this window" in page_lower, \
        "'close this window' not found on final page"

finally:
    now = datetime.now().strftime("%M-%S")
    driver.get_screenshot_as_file("/var/log/selenium-screenshot-entraid-%s.png" % now)
    driver.quit()
