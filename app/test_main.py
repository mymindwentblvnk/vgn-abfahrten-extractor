from assertpy import assert_that
from fastapi.testclient import TestClient

from app.main import app


client = TestClient(app)


def test_read_main():
    response = client.get("/")
    assert_that(response.status_code).is_equal_to(200)
    assert_that(response.json()).is_equal_to({"msg": "Hello World"})
