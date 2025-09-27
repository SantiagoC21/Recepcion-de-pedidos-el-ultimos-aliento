package pos;

import javafx.application.Application;
import javafx.fxml.FXMLLoader;
import javafx.scene.Parent;
import javafx.scene.Scene;
import javafx.stage.Stage;

public class App extends Application {
    @Override
    public void start(Stage stage) throws Exception {
        Parent root = FXMLLoader.load(getClass().getResource("/pos/MainView.fxml"));
        //Scene scene = new Scene(FXMLLoader.load(getClass().getResource("/pos/MainView.fxml")), 1600, 800);
        Scene scene = new Scene(root);
        stage.setScene(scene);
        stage.setTitle("POS JavaFX");
        stage.setMaximized(true);
        stage.show();
    }
    public static void main(String[] args) { launch(args); }
}
