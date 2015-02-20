SET @OLD_UNIQUE_CHECKS=@@UNIQUE_CHECKS, UNIQUE_CHECKS=0;
SET @OLD_FOREIGN_KEY_CHECKS=@@FOREIGN_KEY_CHECKS, FOREIGN_KEY_CHECKS=0;
SET @OLD_SQL_MODE=@@SQL_MODE, SQL_MODE='TRADITIONAL';

CREATE SCHEMA IF NOT EXISTS `ec2cc` DEFAULT CHARACTER SET utf8 ;
USE `ec2cc` ;

-- -----------------------------------------------------
-- Table `ec2cc`.`costs`
-- -----------------------------------------------------
CREATE  TABLE IF NOT EXISTS `ec2cc`.`costs` (
  `id` VARCHAR(10) NOT NULL ,
  `region` VARCHAR(9) NOT NULL ,
  `platform` VARCHAR(7) NOT NULL ,
  `instance_type` VARCHAR(13) NOT NULL ,
  `status` VARCHAR(7) NOT NULL ,
  `cost` DECIMAL(10,4) NOT NULL ,
  `name` VARCHAR(40) NULL ,
  `autoscalinggroup` VARCHAR(40) NULL ,
  `date` DATETIME NOT NULL )
ENGINE = InnoDB;



SET SQL_MODE=@OLD_SQL_MODE;
SET FOREIGN_KEY_CHECKS=@OLD_FOREIGN_KEY_CHECKS;
SET UNIQUE_CHECKS=@OLD_UNIQUE_CHECKS;
