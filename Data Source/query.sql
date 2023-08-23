-- Create Database
CREATE DATABASE kimia farma;

-- Create Table From CSV file
CREATE TABLE penjualan (
	id_distributor varchar(250),
	id_cabang varchar(250),
	id_invoice varchar(250),
	tanggal date,
	id_customer varchar(250), 
	id_barang varchar(250),
	jumlah_barang int,
	unit varchar(250),
	harga numeric,
	mata_uang varchar(250),
	brand_id varchar(250),
	lini varchar(250)
);

CREATE TABLE pelanggan (
	id_customer varchar(250),
	"level" varchar(250),
	nama varchar(250), 
	id_cabang_sales varchar(250), 
	cabang_sales varchar(250),
	id_group varchar(250),
	"group" varchar(250)
);

CREATE TABLE barang (
	kode_barang varchar(250), 
	sektor varchar(250),
	nama_barang varchar(250),
	tipe varchar(250),
	nama_tipe varchar(250),
	kode_lini varchar(250),
	lini varchar(250),
	kemasan varchar(250)
);

-- Change Date Style
ALTER DATABASE kimia_farma
    SET "DateStyle" TO 'ISO, DMY';

-- Create Base Table
CREATE TABLE sales AS (
	SELECT 
		s.id_invoice, 
		s.tanggal, 
		cs.nama, 
		cs.group, 
		cs.cabang_sales,
		b.nama_barang, 
		b.lini as brand,
		s.jumlah_barang,
		s.unit,
		s.harga
	FROM penjualan as s
	JOIN pelanggan as cs ON s.id_customer = cs.id_customer
	JOIN barang as b ON s.id_barang = b.kode_barang
);

-- Create Aggregat Table
CREATE TABLE sales_agg AS (
	SELECT 
		id_invoice, 
		tanggal,
		TO_CHAR(tanggal, 'Month') bulan,
		nama, 
		"group", 
		cabang_sales,
		nama_barang,
		brand,
		jumlah_barang,
		unit,
		harga,
		ROUND(jumlah_barang*harga) as total_harga
	FROM sales
);

-- Create Table Monthly Sales
CREATE TABLE monthly_sales AS (
	SELECT
		date_part('month', tanggal) as bulan_num,
		bulan,
		nama,
		cabang_sales,
		nama_barang,
		brand,
		SUM(jumlah_barang) as total_qty,
		SUM(total_harga) as total_sales,
SUM(SUM(total_harga)) OVER(PARTITION BY bulan, cabang_sales) as branch_total_monthly_sales
	FROM sales_agg
	GROUP BY 1, 2, 3, 4, 5, 6
	ORDER BY 1, 4, 5
);
 
-- Create Table Month-over-Month Sales Performance
WITH mom_growth_rate AS (
	SELECT 
		DATE_TRUNC('month', tanggal) as bulan,
		SUM(total_harga) as total_sales,
		LAG(SUM(total_harga)) OVER(ORDER BY DATE_TRUNC('month', tanggal)) as previous_month_sales,
		(SUM(total_harga) - LAG(SUM(total_harga)) OVER(ORDER BY DATE_TRUNC('month', tanggal))) as monthly_growth,
		CAST(ROUND((SUM(total_harga) - LAG(SUM(total_harga)) OVER(ORDER BY DATE_TRUNC('month', tanggal)))
				  / LAG(SUM(total_harga)) OVER(ORDER BY DATE_TRUNC('month',tanggal)) * 100) as text)
				  || '%' as month_growth_rate
	FROM sales_agg
	GROUP BY 1
	ORDER BY 1
),
avg_order AS (
	SELECT 
		bulan, 
		ROUND(AVG(frequency_purchase),2) AS avg_order_per_customer 
	FROM (
		SELECT
			DISTINCT nama,
			DATE_TRUNC('month', tanggal) AS bulan,
			COUNT(1) AS frequency_purchase
		FROM sales_agg  
		GROUP BY 1, 2
		) a
	GROUP BY 1
	ORDER BY 1
),
qty_trend AS (
	SELECT
		DATE_TRUNC('month', tanggal) AS bulan,
		SUM(jumlah_barang) AS qty_trend
	FROM sales_agg
	GROUP BY 1
	ORDER BY 1
)

SELECT
	a.bulan,
	a.total_sales,
	a.previous_month_sales,
	a.month_growth_rate,
	b.avg_order_per_customer,
	c.qty_trend
FROM mom_growth_rate AS a
JOIN avg_order AS b ON a.bulan = b.bulan
JOIN qty_trend AS c ON a.bulan = c.bulan ; 
