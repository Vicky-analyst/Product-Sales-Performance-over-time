CREATE DATABASE Product_Sales_Analysis;
use Product_Sales_Analysis;

# ADDING PRIMARY KEY TO GEOGRAPHY TABLE
ALTER TABLE geography
ADD PRIMARY KEY (GeographyKey);

# ADDING PRIMARY KEY TO PRODUCT TABLE
ALTER TABLE product
MODIFY COLUMN Product_ID varchar(10);
ALTER TABLE product
ADD PRIMARY KEY (Product_ID);

# ADDING PRIMARY KEY TO WAREHOUSE TABLE
ALTER TABLE ware_house
MODIFY COLUMN Warehouse_ID varchar(10);
ALTER TABLE ware_house
ADD PRIMARY KEY (Warehouse_ID);

#ADDING FOREIGN KEY TO SALES LOG TABLE
ALTER TABLE sales_log
MODIFY COLUMN Product_ID varchar(10);
ALTER TABLE sales_log
ADD CONSTRAINT product_sale
FOREIGN KEY (Product_ID)
REFERENCES product (Product_ID);

ALTER TABLE sales_log
MODIFY COLUMN `Dest. Warehouse` Varchar(10);
ALTER TABLE sales_log
ADD CONSTRAINT sales_wareH
FOREIGN KEY (`Dest. Warehouse`)
REFERENCES ware_house (Warehouse_ID);

ALTER TABLE sales_log
ADD CONSTRAINT sales_geograpy
FOREIGN KEY (Geograpy_Key)
REFERENCES geography (GeographyKey);

ALTER TABLE sales_log
MODIFY COLUMN Order_ID varchar(10);
ALTER TABLE sales_log
ADD unique (Order_ID);

# CREATING TABLE FOR DUPLICATE ENTRY INTO SALES LOG
CREATE TABLE dup_sales_log like sales_log;

# ADDING TRIGGER TO PRIVENT DUPLICATE ENTRY INTO SALES LOG TABLE
DELIMITER //
CREATE trigger dup_sales_log
before insert on sales_log
for each row
begin 
	if exists(select 1 from sales_log  where Order_ID = new.Order_ID)
			then insert into dup_sales_log 
			(`Date`, Order_ID, Product_ID, `Dest. Warehouse`, `Shipping_Time(Expected)`, 
			`Shipping_Time(Actual)`, `Delay_Risk?`, `Total_No._of_Pieces`, 
            `No._of_pieces_sold`, `No._of_Pieces_Returned`, `Avg._Batch_Rating`, 
            Geograpy_Key)
			values(new.Date, 
			new.Order_ID, new.Product_ID, new.`Dest. Warehouse`, new.`Shipping_Time(Expected)`, 
			new.`Shipping_Time(Actual)`, new.`Delay_Risk?`, new.`Total_No._of_Pieces`, 
			new.`No._of_pieces_sold`, new.`No._of_Pieces_Returned`, new.`Avg._Batch_Rating`, 
			new.Geograpy_Key);
            set new.Order_ID = NULL;
    end if;
end //
DELIMITER ;

#CREATING TABLE FOR DUPLICATE ENTRY INTO PRODUCT TABLE
CREATE TABLE dup_product LIKE product

# ADDING TRIGGER TO PREVENT DUPLICATE ENTRY INTO PRODUCT TABLE
DELIMITER //
CREATE TRIGGER dup_product
BEFORE INSERT ON product
FOR EACH ROW
BEGIN 
	IF EXISTS (SELECT 1 FROM product WHERE Product_ID = NEW.Product_ID)
		THEN INSERT INTO dup_product 
        (Product_ID, `Name`, Gender, Selling_Price, 
        Manufac_Cost, `Weight(Kg)`, Product_Link)
		VALUES(NEW.Product_ID, NEW.`Name`, NEW.Gender, NEW.Selling_Price, 
			   NEW.Manufac_Cost, NEW.`Weight(Kg)`, NEW.Product_Link);
		SET  NEW.Product_ID = NULL;
	END IF;
END //
DELIMITER ;