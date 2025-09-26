package pos;

import javafx.fxml.FXML;
import javafx.scene.control.TableView;

public class ClienteController {
    @FXML private TableView<?> tblClientes;

    private Runnable onClose = () -> {};

    public void setOnClose(Runnable r) { this.onClose = r; }

    @FXML private void initialize() {
        // TODO: poblar clientes (demo). Puedes cargar desde BD y setear items en tblClientes.
    }

    @FXML private void onVolver() { onClose.run(); }

    @FXML private void onSeleccionar() {
        // TODO: obtener seleccionado y devolverlo si quieres (mediante otra callback).
        onClose.run();
    }
}
