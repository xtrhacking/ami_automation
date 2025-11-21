USE playground;

CREATE TABLE CONTACT (
    id INT AUTO_INCREMENT PRIMARY KEY,
    nomecompleto VARCHAR(50) NOT NULL,
    cpf VARCHAR(50) NOT NULL,
    religiao VARCHAR(50) NOT NULL,
    email VARCHAR(100) NOT NULL
);

INSERT INTO CONTACT (nomecompleto, cpf, religiao, email) VALUES
('João Silva Santos', '123.456.789-01', 'Católico', 'joao.silva@email.com'),
('Maria Oliveira Lima', '234.567.890-12', 'Evangélico', 'maria.oliveira@email.com'),
('Pedro Souza Costa', '345.678.901-23', 'Católico', 'pedro.souza@email.com'),
('Ana Santos Pereira', '456.789.012-34', 'Espírita', 'ana.santos@email.com'),
('Lucas Ferreira Lima', '567.890.123-45', 'Católico', 'lucas.ferreira@email.com'),
('Julia Costa Silva', '678.901.234-56', 'Budista', 'julia.costa@email.com'),
('Marcos Lima Oliveira', '789.012.345-67', 'Evangélico', 'marcos.lima@email.com'),
('Beatriz Santos Costa', '890.123.456-78', 'Católico', 'beatriz.santos@email.com'),
('Carlos Pereira Silva', '901.234.567-89', 'Espírita', 'carlos.pereira@email.com'),
('Amanda Lima Santos', '012.345.678-90', 'Católico', 'amanda.lima@email.com'),
('Ricardo Oliveira Costa', '123.456.789-02', 'Evangélico', 'ricardo.oliveira@email.com'),
('Fernanda Silva Lima', '234.567.890-13', 'Católico', 'fernanda.silva@email.com'),
('Gabriel Santos Pereira', '345.678.901-24', 'Budista', 'gabriel.santos@email.com'),
('Larissa Costa Oliveira', '456.789.012-35', 'Católico', 'larissa.costa@email.com'),
('Thiago Lima Silva', '567.890.123-46', 'Evangélico', 'thiago.lima@email.com'),
('Isabella Pereira Santos', '678.901.234-57', 'Espírita', 'isabella.pereira@email.com'),
('Rafael Oliveira Costa', '789.012.345-68', 'Católico', 'rafael.oliveira@email.com'),
('Camila Silva Lima', '890.123.456-79', 'Evangélico', 'camila.silva@email.com'),
('Bruno Santos Costa', '901.234.567-80', 'Católico', 'bruno.santos@email.com'),
('Laura Lima Pereira', '012.345.678-91', 'Budista', 'laura.lima@email.com'),
('Daniel Oliveira Silva', '123.456.789-03', 'Católico', 'daniel.oliveira@email.com'),
('Mariana Costa Santos', '234.567.890-14', 'Evangélico', 'mariana.costa@email.com'),
('Felipe Lima Oliveira', '345.678.901-25', 'Espírita', 'felipe.lima@email.com'),
('Paula Santos Silva', '456.789.012-36', 'Católico', 'paula.santos@email.com'),
('Gustavo Pereira Costa', '567.890.123-47', 'Evangélico', 'gustavo.pereira@email.com'),
('Carolina Lima Santos', '678.901.234-58', 'Católico', 'carolina.lima@email.com'),
('Henrique Silva Oliveira', '789.012.345-69', 'Budista', 'henrique.silva@email.com'),
('Vitória Santos Costa', '890.123.456-70', 'Católico', 'vitoria.santos@email.com'),
('Leonardo Lima Pereira', '901.234.567-81', 'Evangélico', 'leonardo.lima@email.com'),
('Sophia Oliveira Silva', '012.345.678-92', 'Espírita', 'sophia.oliveira@email.com'),
('Matheus Costa Santos', '123.456.789-04', 'Católico', 'matheus.costa@email.com'),
('Valentina Lima Oliveira', '234.567.890-15', 'Evangélico', 'valentina.lima@email.com'),
('Eduardo Santos Silva', '345.678.901-26', 'Católico', 'eduardo.santos@email.com'),
('Luiza Pereira Costa', '456.789.012-37', 'Budista', 'luiza.pereira@email.com'),
('Arthur Lima Santos', '567.890.123-48', 'Católico', 'arthur.lima@email.com'),
('Clara Silva Oliveira', '678.901.234-59', 'Evangélico', 'clara.silva@email.com'),
('Miguel Santos Costa', '789.012.345-70', 'Espírita', 'miguel.santos@email.com'),
('Alice Lima Pereira', '890.123.456-81', 'Católico', 'alice.lima@email.com'),
('Vicente Oliveira Silva', '901.234.567-92', 'Evangélico', 'vicente.oliveira@email.com'),
('Helena Costa Santos', '012.345.678-93', 'Católico', 'helena.costa@email.com'),
('Bernardo Lima Oliveira', '123.456.789-05', 'Budista', 'bernardo.lima@email.com'),
('Isadora Santos Silva', '234.567.890-16', 'Católico', 'isadora.santos@email.com'),
('Pedro Lima Costa', '345.678.901-27', 'Evangélico', 'pedro.lima@email.com'),
('Júlia Oliveira Santos', '456.789.012-38', 'Espírita', 'julia.oliveira@email.com'),
('Davi Silva Pereira', '567.890.123-49', 'Católico', 'davi.silva@email.com'),
('Manuela Costa Lima', '678.901.234-60', 'Evangélico', 'manuela.costa@email.com'),
('Samuel Santos Oliveira', '789.012.345-71', 'Católico', 'samuel.santos@email.com'),
('Lívia Lima Silva', '890.123.456-82', 'Budista', 'livia.lima@email.com'),
('Benjamin Pereira Costa', '901.234.567-93', 'Católico', 'benjamin.pereira@email.com'),
('Cecília Santos Lima', '012.345.678-94', 'Evangélico', 'cecilia.santos@email.com'),
('Thomas Oliveira Silva', '123.456.789-06', 'Espírita', 'thomas.oliveira@email.com'),
('Heloísa Costa Santos', '234.567.890-17', 'Católico', 'heloisa.costa@email.com'),
('Nicolas Lima Pereira', '345.678.901-28', 'Evangélico', 'nicolas.lima@email.com'); 


CREATE TABLE SECRETS_TABLE (
    id INT AUTO_INCREMENT PRIMARY KEY,
    SECRET_VALUE VARCHAR(50) NOT NULL
);

INSERT INTO SECRETS_TABLE (SECRET_VALUE) VALUES ("Extreme{564beb85ee0a89614f4f480ca167844075b4bab0}");


