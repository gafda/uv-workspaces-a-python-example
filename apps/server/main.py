from logger import setup_logger
from db import get_one
from colorama import Fore, Style

def main():
    lg = setup_logger("logs/server.log")
    lg.info("Hello from server")
    lg.info(f"Db call value: {get_one()}")
    
    lg.info(f"{Fore.RED}Hello from server using colorama{Style.RESET_ALL}")


if __name__ == "__main__":
    main()
