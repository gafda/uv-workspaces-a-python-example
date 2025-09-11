from logger import setup_logger

def main():
    lg = setup_logger("logs/another-server.log")
    lg.info("Hello from another-server!")


if __name__ == "__main__":
    main()
