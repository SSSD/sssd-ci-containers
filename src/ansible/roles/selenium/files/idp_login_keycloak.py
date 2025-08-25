#!/opt/test_venv/bin/python3

import sys

from selenium import webdriver
from datetime import datetime
from packaging.version import parse
from selenium.webdriver.firefox.options import Options
from selenium.webdriver.common.by import By
from selenium.webdriver.support.ui import WebDriverWait
from selenium.webdriver.support import expected_conditions as EC

if (len(sys.argv) - 1) != 3:
    print("Incorrect number of arguments")
    print(f"Usage: {sys.argv[0]} <verification_uri> <username> <password>")
    sys.exit(2)

verification_uri = sys.argv[1]
username = sys.argv[2]
password = sys.argv[3]

options = Options()
options.binary_location = "/opt/test_venv/bin/firefox"
if  parse(webdriver.__version__) < parse('4.10.0'):
    options.headless = True
    driver = webdriver.Firefox(executable_path="/opt/test_venv/bin/geckodriver",
                            options=options)
else:
    options.add_argument('-headless')
    service = webdriver.FirefoxService(
        executable_path="/opt/test_venv/bin/geckodriver",
        service_args=['--log', 'debug'], log_output="/tmp/123gecko.log")
    driver = webdriver.Firefox(options=options, service=service)

driver.get(verification_uri)
try:
    element = WebDriverWait(driver, 30).until(
        EC.presence_of_element_located((By.ID, "username")))
    driver.find_element(By.ID, "username").send_keys(username)
    driver.find_element(By.ID, "password").send_keys(password)
    driver.find_element(By.ID, "kc-login").click()
    element = WebDriverWait(driver, 90).until(
        EC.presence_of_element_located((By.ID, "kc-login")))
    driver.find_element(By.ID, "kc-login").click()
    assert "Device Login Successful" in driver.page_source
finally:
    now = datetime.now().strftime("%M-%S")
    driver.get_screenshot_as_file("/var/log/selenium-screenshot-%s.png" % now)
    driver.quit()

